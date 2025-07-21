setup:
	uv sync
	@echo "Run these commands:"
	@echo "  source .venv/bin/activate"
	@echo "  source .env"


set shell := ["bash", "-c"]
python := "./.venv/bin/python"

compile:
	dbt parse
	{{python}} ./scripts/generate_dependency_graph.py

deploy:
	just compile
	databricks bundle deploy

destroy:
	databricks bundle destroy --auto-approve