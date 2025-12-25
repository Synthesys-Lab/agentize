# Default target
.PHONY: test agentize help

test:
	./tests/test-all.sh

# Agentize target - creates SDK for projects
agentize:
	@if [ -z "$(AGENTIZE_PROJECT_PATH)" ]; then \
		echo "Error: AGENTIZE_PROJECT_PATH is required"; \
		exit 1; \
	fi
	@# Set default mode to init if not specified
	@MODE=$(AGENTIZE_MODE); \
	if [ -z "$$MODE" ]; then MODE="init"; fi; \
	SOURCE_PATH=$(AGENTIZE_SOURCE_PATH); \
	if [ -z "$$SOURCE_PATH" ]; then SOURCE_PATH="src"; fi; \
	echo "Mode: $$MODE"; \
	echo "Target path: $(AGENTIZE_PROJECT_PATH)"; \
	if [ "$$MODE" = "init" ]; then \
		if [ -z "$(AGENTIZE_PROJECT_NAME)" ]; then \
			echo "Error: AGENTIZE_PROJECT_NAME is required for init mode"; \
			exit 1; \
		fi; \
		if [ -z "$(AGENTIZE_PROJECT_LANG)" ]; then \
			echo "Error: AGENTIZE_PROJECT_LANG is required for init mode"; \
			exit 1; \
		fi; \
		if [ ! -d "templates/$(AGENTIZE_PROJECT_LANG)" ]; then \
			echo "Error: Template for language '$(AGENTIZE_PROJECT_LANG)' not found"; \
			echo "Available languages: c, cxx, python"; \
			exit 1; \
		fi; \
		echo "Creating SDK for project: $(AGENTIZE_PROJECT_NAME)"; \
		echo "Language: $(AGENTIZE_PROJECT_LANG)"; \
		echo "Source path: $$SOURCE_PATH"; \
		echo "Initializing SDK structure..."; \
		if [ -d "$(AGENTIZE_PROJECT_PATH)" ]; then \
			if [ -n "$$(ls -A '$(AGENTIZE_PROJECT_PATH)' 2>/dev/null)" ]; then \
				echo "Error: Directory '$(AGENTIZE_PROJECT_PATH)' exists and is not empty."; \
				echo "Please use an empty directory or a non-existent path for init mode."; \
				exit 1; \
			fi; \
			echo "Directory exists and is empty, proceeding..."; \
		else \
			echo "Creating directory '$(AGENTIZE_PROJECT_PATH)'..."; \
			mkdir -p "$(AGENTIZE_PROJECT_PATH)"; \
		fi; \
		cp -r templates/$(AGENTIZE_PROJECT_LANG)/* "$(AGENTIZE_PROJECT_PATH)/"; \
		echo "Copying Claude Code configuration..."; \
		cp -r claude "$(AGENTIZE_PROJECT_PATH)/.claude"; \
		if [ -f "templates/claude/CLAUDE.md.template" ]; then \
			sed -e "s/{{PROJECT_NAME}}/$(AGENTIZE_PROJECT_NAME)/g" \
			    -e "s/{{PROJECT_LANG}}/$(AGENTIZE_PROJECT_LANG)/g" \
			    templates/claude/CLAUDE.md.template > "$(AGENTIZE_PROJECT_PATH)/CLAUDE.md"; \
		fi; \
		cp -r templates/claude/docs "$(AGENTIZE_PROJECT_PATH)/"; \
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
			echo "Error: Project path '$(AGENTIZE_PROJECT_PATH)' does not exist."; \
			echo "Use AGENTIZE_MODE=init to create it."; \
			exit 1; \
		fi; \
		if [ ! -d "$(AGENTIZE_PROJECT_PATH)/.claude" ]; then \
			echo "Error: Directory '$(AGENTIZE_PROJECT_PATH)' is not a valid SDK structure."; \
			echo "Missing '.claude/' directory."; \
			echo "Please ensure this is an SDK created with 'make agentize' before using update mode."; \
			exit 1; \
		fi; \
		echo "Updating Claude Code configuration..."; \
		echo "  Backing up existing .claude/ to .claude.backup/"; \
		cp -r "$(AGENTIZE_PROJECT_PATH)/.claude" "$(AGENTIZE_PROJECT_PATH)/.claude.backup"; \
		cp -r claude/* "$(AGENTIZE_PROJECT_PATH)/.claude/"; \
		echo "  Updated .claude/settings.json, commands, skills, and hooks"; \
		if [ ! -f "$(AGENTIZE_PROJECT_PATH)/docs/git-msg-tags.md" ]; then \
			echo "  Creating missing docs/git-msg-tags.md..."; \
			DETECTED_LANG=""; \
			if [ -f "$(AGENTIZE_PROJECT_PATH)/requirements.txt" ] || \
			   [ -f "$(AGENTIZE_PROJECT_PATH)/pyproject.toml" ] || \
			   [ -n "$$(find '$(AGENTIZE_PROJECT_PATH)' -maxdepth 2 -name '*.py' -print -quit 2>/dev/null)" ]; then \
				DETECTED_LANG="python"; \
			elif [ -f "$(AGENTIZE_PROJECT_PATH)/CMakeLists.txt" ]; then \
				if grep -q "project.*CXX" "$(AGENTIZE_PROJECT_PATH)/CMakeLists.txt" 2>/dev/null; then \
					DETECTED_LANG="cxx"; \
				else \
					DETECTED_LANG="c"; \
				fi; \
			fi; \
			if [ -n "$$DETECTED_LANG" ]; then \
				echo "    Detected language: $$DETECTED_LANG"; \
				mkdir -p "$(AGENTIZE_PROJECT_PATH)/docs"; \
				if [ "$$DETECTED_LANG" = "python" ]; then \
					sed -e "/{{#if_python}}/d" \
					    -e "/{{\/if_python}}/d" \
					    -e "/{{#if_c_or_cxx}}/,/{{\/if_c_or_cxx}}/d" \
					    templates/claude/docs/git-msg-tags.md.template > "$(AGENTIZE_PROJECT_PATH)/docs/git-msg-tags.md"; \
				else \
					sed -e "/{{#if_python}}/,/{{\/if_python}}/d" \
					    -e "/{{#if_c_or_cxx}}/d" \
					    -e "/{{\/if_c_or_cxx}}/d" \
					    templates/claude/docs/git-msg-tags.md.template > "$(AGENTIZE_PROJECT_PATH)/docs/git-msg-tags.md"; \
				fi; \
				echo "    Created docs/git-msg-tags.md"; \
			else \
				echo "    Warning: Could not detect project language, skipping git-msg-tags.md creation"; \
			fi; \
		else \
			echo "  Existing CLAUDE.md and docs/git-msg-tags.md were preserved"; \
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