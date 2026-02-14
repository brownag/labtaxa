.PHONY: help docker docker-test clean doc check install test build

# Default target
help:
	@echo "labtaxa development tasks"
	@echo ""
	@echo "Docker (primary workflow):"
	@echo "  make docker       - Build Docker image (cached, fast) for development"
	@echo "  make docker-test  - Build Docker image (clean) for validation before push"
	@echo ""
	@echo "R Package:"
	@echo "  make doc          - Generate documentation (roxygen2)"
	@echo "  make check        - Run R CMD CHECK"
	@echo "  make install      - Install package locally"
	@echo "  make test         - Run tests"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean        - Remove build artifacts"
	@echo ""
	@echo "Combined:"
	@echo "  make all          - Document, check, test (pre-commit validation)"

# R Package targets
doc:
	Rscript -e "devtools::document()" && echo "Documentation generated"

check:
	Rscript -e "devtools::check()" || (echo "Check failed"; exit 1)

install:
	Rscript -e "devtools::install(upgrade = 'never')" && echo "Package installed"

build:
	Rscript -e "devtools::build()" && echo "Package built"

test:
	Rscript -e "devtools::test()" || (echo "Tests failed"; exit 1)

# Docker targets
docker:
	./scripts/build-docker.sh

docker-test:
	./scripts/build-docker.sh --test

# Cleanup targets
clean:
	@echo "Cleaning R build artifacts..."
	rm -rf *.tar.gz *.Rcheck src/*.o src/*.so
	find . -name "*.Rout" -delete
	find . -name ".Rhistory" -delete
	@echo "Cleaned"

# Combined workflows
all: doc check test
	@echo "All checks passed"

.DEFAULT_GOAL := help
