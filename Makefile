SRCDIR=uninuvola_init
DOCSDIR=docs
DOCSINDEXFILE=index.md


.PHONY: lint
lint:
	poetry run pylint $(shell git ls-files '*.py')

.PHONY: docs
docs:
	mkdir -p $(DOCSDIR) && \
		poetry run pydoc-markdown -I $(SRCDIR) --render-toc > $(DOCSDIR)/$(DOCSINDEXFILE)
