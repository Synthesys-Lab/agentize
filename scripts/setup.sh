#!/usr/bin/env bash
# Setup helper for agentize cross-project shell functions
# Generates configuration and provides setup instructions

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/agentize"
CONFIG_FILE="$CONFIG_DIR/agentize.env"

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

# Generate or update config file
generate_config() {
    echo "# Agentize environment configuration" > "$CONFIG_FILE"
    echo "# Generated on $(date)" >> "$CONFIG_FILE"
    echo "" >> "$CONFIG_FILE"
    echo "export AGENTIZE_HOME=\"$PROJECT_ROOT\"" >> "$CONFIG_FILE"
    echo "source \"\$AGENTIZE_HOME/scripts/wt-functions.sh\"" >> "$CONFIG_FILE"
    echo "source \"\$AGENTIZE_HOME/scripts/agentize-functions.sh\"" >> "$CONFIG_FILE"
}

# Print setup instructions
print_instructions() {
    echo -e "${GREEN}=== Agentize Setup ===${NC}"
    echo ""
    echo "Configuration file created at:"
    echo -e "  ${BLUE}$CONFIG_FILE${NC}"
    echo ""
    echo -e "${YELLOW}Manual Setup (Recommended):${NC}"
    echo ""
    echo "Add the following to your shell RC file (~/.bashrc, ~/.zshrc, etc.):"
    echo ""
    echo -e "${BLUE}source \"$CONFIG_FILE\"${NC}"
    echo ""
    echo "Then reload your shell:"
    echo -e "  ${BLUE}source ~/.bashrc${NC}  # or ~/.zshrc, etc."
    echo ""
    echo -e "${YELLOW}What this enables:${NC}"
    echo "  - Run ${BLUE}wt spawn 42${NC} from any directory"
    echo "  - Worktrees always created in ${BLUE}$PROJECT_ROOT/trees/${NC}"
    echo "  - Commands: spawn, list, remove, prune"
    echo ""
    echo "  - Run ${BLUE}agentize init --name xxx --lang cxx${NC} from any directory"
    echo "  - Run ${BLUE}agentize update${NC} from project root or subdirectories"
    echo ""
}

# Detect shell RC file
detect_shell_rc() {
    if [ -n "$BASH_VERSION" ]; then
        if [ -f "$HOME/.bashrc" ]; then
            echo "$HOME/.bashrc"
        elif [ -f "$HOME/.bash_profile" ]; then
            echo "$HOME/.bash_profile"
        fi
    elif [ -n "$ZSH_VERSION" ]; then
        echo "$HOME/.zshrc"
    fi
}

# Install configuration automatically (with confirmation)
install_config() {
    local rc_file
    rc_file=$(detect_shell_rc)

    if [ -z "$rc_file" ]; then
        echo -e "${YELLOW}Warning: Could not detect shell RC file${NC}"
        echo "Please add the source line manually to your shell RC file."
        return 1
    fi

    echo -e "${YELLOW}Automatic installation will add the following line to $rc_file:${NC}"
    echo ""
    echo -e "${BLUE}source \"$CONFIG_FILE\"${NC}"
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Check if already sourced
        if grep -q "source \"$CONFIG_FILE\"" "$rc_file" 2>/dev/null || \
           grep -q "source '$CONFIG_FILE'" "$rc_file" 2>/dev/null; then
            echo -e "${GREEN}✓ Already configured in $rc_file${NC}"
        else
            echo "" >> "$rc_file"
            echo "# Agentize cross-project shell functions" >> "$rc_file"
            echo "source \"$CONFIG_FILE\"" >> "$rc_file"
            echo -e "${GREEN}✓ Configuration added to $rc_file${NC}"
        fi

        echo ""
        echo "Reload your shell to activate:"
        echo -e "  ${BLUE}source $rc_file${NC}"
    else
        echo "Installation cancelled. Use manual setup instructions above."
    fi
}

# Main script logic
main() {
    # Generate config file
    generate_config

    # Check for --install flag
    if [ "$1" = "--install" ]; then
        print_instructions
        echo ""
        install_config
    else
        print_instructions
        echo -e "${YELLOW}For automated installation:${NC}"
        echo -e "  ${BLUE}$0 --install${NC}"
        echo ""
    fi
}

main "$@"
