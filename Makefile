# Default target
.PHONY: test agentize help

test:
	./tests/test-all.sh

# Agentize target - creates SDK for projects
agentize:
	@if [ -z "$(AGENTIZE_PROJECT_NAME)" ]; then \
		echo "Error: AGENTIZE_PROJECT_NAME is required"; \
		exit 1; \
	fi
	@if [ -z "$(AGENTIZE_PROJECT_PATH)" ]; then \
		echo "Error: AGENTIZE_PROJECT_PATH is required"; \
		exit 1; \
	fi
	@if [ -z "$(AGENTIZE_PROJECT_LANG)" ]; then \
		echo "Error: AGENTIZE_PROJECT_LANG is required"; \
		exit 1; \
	fi
	@# Check if language template exists
	@if [ ! -d "templates/$(AGENTIZE_PROJECT_LANG)" ]; then \
		echo "Error: Template for language '$(AGENTIZE_PROJECT_LANG)' not found"; \
		echo "Available languages: c, cxx, python"; \
		exit 1; \
	fi
	@# Set default mode to init if not specified
	@MODE=$(AGENTIZE_MODE); \
	if [ -z "$$MODE" ]; then MODE="init"; fi; \
	SOURCE_PATH=$(AGENTIZE_SOURCE_PATH); \
	if [ -z "$$SOURCE_PATH" ]; then SOURCE_PATH="src"; fi; \
	echo "Creating SDK for project: $(AGENTIZE_PROJECT_NAME)"; \
	echo "Language: $(AGENTIZE_PROJECT_LANG)"; \
	echo "Mode: $$MODE"; \
	echo "Target path: $(AGENTIZE_PROJECT_PATH)"; \
	echo "Source path: $$SOURCE_PATH"; \
	if [ "$$MODE" = "init" ]; then \
		echo "Initializing SDK structure..."; \
		mkdir -p "$(AGENTIZE_PROJECT_PATH)"; \
		cp -r templates/$(AGENTIZE_PROJECT_LANG)/* "$(AGENTIZE_PROJECT_PATH)/"; \
		if [ -f "$(AGENTIZE_PROJECT_PATH)/bootstrap.sh" ]; then \
			echo "Running bootstrap script..."; \
			chmod +x "$(AGENTIZE_PROJECT_PATH)/bootstrap.sh"; \
			(cd "$(AGENTIZE_PROJECT_PATH)" && \
			AGENTIZE_PROJECT_NAME="$(AGENTIZE_PROJECT_NAME)" \
			AGENTIZE_PROJECT_PATH="$(AGENTIZE_PROJECT_PATH)" \
			AGENTIZE_SOURCE_PATH="$$SOURCE_PATH" \
			./bootstrap.sh); \
		fi; \
		echo "SDK initialized successfully at $(AGENTIZE_PROJECT_PATH)"; \
	elif [ "$$MODE" = "update" ]; then \
		echo "Updating SDK structure..."; \
		if [ ! -d "$(AGENTIZE_PROJECT_PATH)" ]; then \
			echo "Error: Project path does not exist. Use AGENTIZE_MODE=init to create it."; \
			exit 1; \
		fi; \
		echo "SDK updated successfully at $(AGENTIZE_PROJECT_PATH)"; \
	else \
		echo "Error: Invalid mode '$$MODE'. Supported modes: init, update"; \
		exit 1; \
	fi

help:
	@echo "Available targets:"
	@echo "  make test                - Run all tests"
	@echo "  make agentize            - Create SDK for a project"
	@echo ""
	@echo "Agentize usage:"
	@echo "  make agentize \\"
	@echo "    AGENTIZE_PROJECT_NAME=\"your_project\" \\"
	@echo "    AGENTIZE_PROJECT_PATH=\"/path/to/project\" \\"
	@echo "    AGENTIZE_PROJECT_LANG=\"c\" \\"
	@echo "    AGENTIZE_MODE=\"init\""