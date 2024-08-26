.PHONY: lint

lint:
	poetry run pylint $(shell git ls-files '*.py')
