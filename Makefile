# ============================================================================
# Agentize SDK - AI Development Workflow Automation
# ============================================================================

# Public configuration variables
AGENTIZE_MASTER_PROJ ?= ../..
AGENTIZE_PROJ_NAME ?= MyProject
AGENTIZE_MODE ?= init
AGENTIZE_LANG ?=
AGENTIZE_IMPL_DIR ?= src

# Internal variables
SCRIPTS_DIR := scripts
CLAUDE_DIR := claude
INSTALL_SCRIPT := $(SCRIPTS_DIR)/install.sh

# ============================================================================
# Main Targets
# ============================================================================

.PHONY: help
help:
	@echo "┌─────────────────────────────────────────────────────────────┐"
	@echo "│  Agentize - AI Development SDK                             │"
	@echo "└─────────────────────────────────────────────────────────────┘"
	@echo ""
	@echo "Usage:"
	@echo "  make agentize [OPTIONS]"
	@echo ""
	@echo "Options:"
	@echo "  AGENTIZE_MASTER_PROJ=<path>    Target project directory (default: ../..)"
	@echo "  AGENTIZE_PROJ_NAME=<name>      Project name (default: MyProject)"
	@echo "  AGENTIZE_MODE=<init|port|update>  Installation mode (default: init)"
	@echo "  AGENTIZE_LANG=<langs>          Languages: python,c,cpp,rust (default: cpp)"
	@echo "  AGENTIZE_IMPL_DIR=<dir>        Implementation directory (default: src)"
	@echo ""
	@echo "Modes:"
	@echo "  init   - Initialize new project (creates Makefile, docs/, README, etc.)"
	@echo "  port   - Port to existing project (only installs .claude/ configs)"
	@echo "  update - Update existing .claude/ to latest SDK (preserves customizations)"
	@echo ""
	@echo "Examples:"
	@echo "  make agentize"
	@echo "  make agentize AGENTIZE_MASTER_PROJ=../../my-project AGENTIZE_PROJ_NAME=\"My Project\""
	@echo "  make agentize AGENTIZE_MODE=port  # Port to existing project"
	@echo "  make agentize AGENTIZE_MODE=update  # Update existing installation"
	@echo "  make agentize AGENTIZE_LANG=python AGENTIZE_IMPL_DIR=lib  # Python library"
	@echo "  make agentize AGENTIZE_LANG=python,cpp  # Python with C++ extensions"
	@echo ""
	@echo "Required interface in target project:"
	@echo "  - source setup.sh      # Environment setup"
	@echo "  - make build           # Build project"
	@echo "  - make test            # Run tests"
	@echo ""

.PHONY: agentize
agentize:
	@echo "┌─────────────────────────────────────────────────────────────┐"
	@echo "│  Installing Agentize to $(AGENTIZE_MASTER_PROJ)"
	@echo "└─────────────────────────────────────────────────────────────┘"
	@bash $(INSTALL_SCRIPT) \
		"$(AGENTIZE_MASTER_PROJ)" \
		"$(AGENTIZE_PROJ_NAME)" \
		"$(AGENTIZE_MODE)" \
		"$(AGENTIZE_LANG)" \
		"$(AGENTIZE_IMPL_DIR)"

.PHONY: clean
clean:
	@echo "Cleaning temporary artifacts..."
	@rm -rf /tmp/agentize-test-*
	@echo "✓ Clean complete"

.DEFAULT_GOAL := help
