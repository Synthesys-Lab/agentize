# Default target
.PHONY: test agentize help

test:
	./tests/test-all.sh

# Agentize target - creates SDK for projects
agentize:
	@# Set default mode to init if not specified
	@MODE=$(AGENTIZE_MODE); \
	if [ -z "$$MODE" ]; then MODE="init"; fi; \
	echo "Mode: $$MODE"; \
	echo "Target path: $(AGENTIZE_PROJECT_PATH)"; \
	./scripts/check-parameter.sh "$$MODE" "$(AGENTIZE_PROJECT_PATH)" "$(AGENTIZE_PROJECT_NAME)" "$(AGENTIZE_PROJECT_LANG)" || exit 1; \
	if [ "$$MODE" = "init" ]; then \
		export AGENTIZE_PROJECT_PATH="$(AGENTIZE_PROJECT_PATH)"; \
		export AGENTIZE_PROJECT_NAME="$(AGENTIZE_PROJECT_NAME)"; \
		export AGENTIZE_PROJECT_LANG="$(AGENTIZE_PROJECT_LANG)"; \
		export AGENTIZE_SOURCE_PATH="$(AGENTIZE_SOURCE_PATH)"; \
		./scripts/agentize-init.sh; \
	elif [ "$$MODE" = "update" ]; then \
		export AGENTIZE_PROJECT_PATH="$(AGENTIZE_PROJECT_PATH)"; \
		./scripts/agentize-update.sh;
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