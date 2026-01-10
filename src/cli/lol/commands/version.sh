#!/usr/bin/env bash
# lol_cmd_version: Display version information

# lol_cmd_version: Display version information
lol_cmd_version() {
    # Get installation commit from AGENTIZE_HOME
    local install_commit="Not a git repository"
    if git -C "$AGENTIZE_HOME" rev-parse HEAD >/dev/null 2>&1; then
        install_commit=$(git -C "$AGENTIZE_HOME" rev-parse HEAD)
    fi

    # Get project commit from .agentize.yaml
    local project_commit="Not set"
    local agentize_yaml=""

    # Search for .agentize.yaml in current directory and parents
    local search_path="$PWD"
    while [ "$search_path" != "/" ]; do
        if [ -f "$search_path/.agentize.yaml" ]; then
            agentize_yaml="$search_path/.agentize.yaml"
            break
        fi
        search_path="$(dirname "$search_path")"
    done

    # If found, extract agentize.commit field
    if [ -n "$agentize_yaml" ]; then
        # Parse YAML to extract agentize.commit value
        # Look for line matching "  commit: <hash>" under "agentize:" section
        local in_agentize_section=0
        while IFS= read -r line; do
            # Check if we're entering agentize section
            if echo "$line" | grep -q "^agentize:"; then
                in_agentize_section=1
                continue
            fi

            # Check if we've left the agentize section (new top-level key)
            if [ "$in_agentize_section" = "1" ] && echo "$line" | grep -q "^[a-z]"; then
                in_agentize_section=0
            fi

            # Extract commit if we're in agentize section
            if [ "$in_agentize_section" = "1" ]; then
                if echo "$line" | grep -q "^  commit:"; then
                    project_commit=$(echo "$line" | sed 's/^  commit: *//')
                    break
                fi
            fi
        done < "$agentize_yaml"
    fi

    # Display version information
    echo "Installation: $install_commit"
    echo "Last update:  $project_commit"
}
