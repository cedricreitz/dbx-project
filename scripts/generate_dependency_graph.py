import json
import os
from collections import defaultdict, deque

import yaml


class WorkflowGenerator:
    def __init__(
        self,
        default_yaml_path: str = f"{os.getcwd()}/scripts/defaults.yml",
        manifest_path: str = f"{os.getcwd()}/target/manifest.json",
        project_directory: str = "../",
        profiles_directory: str = "dbt_profiles/",
        base_command: str = "dbt run --target=${bundle.target} --vars='{full_refresh: {{job.parameters.full_refresh}}, full_refresh_from: {{job.parameters.full_refresh_from}}, full_refresh_whitelist: {{job.parameters.full_refresh_whitelist}}, full_refresh_blacklist: {{job.parameters.full_refresh_blacklist}} }' --select",
    ):
        self._manifest_path = manifest_path
        self._default_yaml_path = default_yaml_path

        self._read_default_yaml()
        self._read_manifest_json()
        self._extract_tables()
        self._topological_sort()
        self._generate_task_array(
            self._environment_key,
            project_directory,
            profiles_directory,
            base_command,
        )
        self._create_composed_dict()

    def _read_default_yaml(self):
        with open(self._default_yaml_path, "r") as file:
            default_yaml: dict = yaml.safe_load(file)
        self._default_yaml = default_yaml
        self._workflow_name = [
            key
            for key, _ in self._default_yaml.get("resources", {})
            .get("jobs", {})
            .items()
        ][0]
        self._environment_key = (
            self._default_yaml.get("resources", {})
            .get("jobs", {})
            .get(self._workflow_name, {})
            .get("environments")[0]
            .get("environment_key")
        )

    def _read_manifest_json(self):
        with open(self._manifest_path, "r") as file:
            manifest: dict = json.load(file)
        self._manifest = manifest

    def _extract_tables(self):
        extracted_tables = {}
        for node_id, node in self._manifest.get("nodes", {}).items():
            if node.get("resource_type") == "model":
                # Extract database, schema, and table name
                model_name = node["name"]

                # Parse based on your folder structure
                path_parts = node["path"].split("/")
                if len(path_parts) >= 3:
                    database = path_parts[0]
                    schema = path_parts[1]

                    # Get dependencies
                    depends_on = []
                    for dep in node.get("depends_on", {}).get("nodes", []):
                        if dep.startswith("model."):
                            depends_on.append(dep)

                    extracted_tables[node_id] = {
                        "name": model_name,
                        "database": database,
                        "schema": schema,
                        "path": node["path"],
                        "depends_on": depends_on,
                        "task_name": f"{model_name}",
                    }
        self._tables: dict = extracted_tables

    def _topological_sort(self):
        """
        Performs topological sorting on the tables extracted from the manifest file.

        Raises:
            ValueError: If a circular dependency is detected
        """
        # Build adjacency list and calculate in-degrees
        graph = defaultdict(list)  # node -> list of dependent nodes
        in_degree = defaultdict(int)  # node -> number of dependencies

        # Initialize all nodes with in-degree 0
        for node in self._tables:
            in_degree[node] = 0

        # Build the graph and calculate in-degrees
        for node, node_data in self._tables.items():
            dependencies = node_data.get("depends_on", [])
            in_degree[node] = len(dependencies)

            # For each dependency, add this node as a dependent
            for dependency in dependencies:
                if (
                    dependency in self._tables
                ):  # Only consider dependencies that exist in our dict
                    graph[dependency].append(node)

        # Find all nodes with no dependencies (in-degree 0)
        queue = deque([node for node in self._tables if in_degree[node] == 0])
        result = []

        # Process nodes with no dependencies
        while queue:
            current = queue.popleft()
            result.append(current)

            # For each dependent of the current node
            for dependent in graph[current]:
                in_degree[dependent] -= 1
                # If dependent now has no remaining dependencies, add it to queue
                if in_degree[dependent] == 0:
                    queue.append(dependent)

        # Check for circular dependencies
        if len(result) != len(self._tables):
            remaining_nodes = [node for node in self._tables if node not in result]
            raise ValueError(
                f"Circular dependency detected among nodes: {remaining_nodes}"
            )

        self._sorted_tables = {key: self._tables[key] for key in result}

    def _generate_task_array(
        self,
        environment_key: str,
        project_directory: str,
        profiles_directory: str,
        base_command: str,
    ):
        tasks = []
        for _, value in self._sorted_tables.items():
            task_key = value.get("task_name").replace(".", "-")
            model_name = value.get("task_name")
            schema = value.get("schema")
            dependencies = [
                {
                    "task_key": self._sorted_tables.get(x, {})
                    .get("task_name")
                    .replace(".", "-")
                }
                for x in value.get("depends_on")
            ]
            task_dict = {
                "task_key": task_key,
                "environment_key": environment_key,
                "dbt_task": {
                    "project_directory": project_directory,
                    "commands": [f'{base_command} "{model_name}"'],
                    "schema": schema,
                    "profiles_directory": profiles_directory,
                },
            }
            if len(dependencies) > 0:
                task_dict["depends_on"] = dependencies
            tasks.append(task_dict)
        self._tasks = tasks

    def _create_composed_dict(self):
        self.composed_dict = self._default_yaml
        self.composed_dict["resources"]["jobs"][self._workflow_name]["tasks"] = (
            self._tasks
        )

    def write_yaml_pipeline(self, filename: str | None = None):
        if not filename:
            filename = f"{os.getcwd()}/pipelines/{self._workflow_name}.yml"
        with open(filename, "w") as file:
            yaml.safe_dump(self.composed_dict, file, sort_keys=False)


test = WorkflowGenerator()
test.write_yaml_pipeline()
