#!/usr/bin/env python3
"""
Run agentize container with volume passthrough.

This script mounts external resources into the container:
- ~/.claude-code-router/config.json -> /home/agentizer/.claude-code-router/config.json
- ~/.config/gh -> /home/agentizer/.config/gh (GitHub CLI credentials, read-write for token refresh)
- ~/.git-credentials -> /home/agentizer/.git-credentials
- ~/.gitconfig -> /home/agentizer/.gitconfig
- Current agentize project directory -> /workspace/agentize
- GITHUB_TOKEN environment variable (if set)

Container runtime is detected in priority order:
1. Local config file (sandbox/agentize.toml or ./agentize.toml)
2. ~/.config/agentize/agentize.toml config file
3. CONTAINER_RUNTIME environment variable
4. Auto-detection (podman preferred if available)
5. Default to docker
"""

import argparse
import hashlib
import json
import os
import platform
import shlex
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Optional

# Python 3.11+ has tomllib built-in, older versions need tomli
if sys.version_info >= (3, 11):
    import tomllib
else:
    import tomli as tomllib

# Cache file to store image hash for rebuild detection
CACHE_DIR = Path.home() / ".cache" / "agentize"
CACHE_FILE = CACHE_DIR / "sandbox-image.json"

IMAGE_NAME = "agentize-sandbox"

# Files that trigger rebuild when modified (relative to context/sandbox directory)
BUILD_TRIGGER_FILES = [
    "Dockerfile",
    "install.sh",
    "entrypoint.sh",
]


def get_container_runtime() -> str:
    """Determine the container runtime to use.

    Priority:
    1. Local config file (sandbox/agentize.toml or ./agentize.toml)
    2. ~/.config/agentize/agentize.toml config file
    3. CONTAINER_RUNTIME environment variable
    4. Auto-detection (podman preferred if available)
    5. Default to docker
    """
    # Priority 1: Local config file
    script_dir = Path(__file__).parent.resolve()
    local_configs = [
        script_dir / "agentize.toml",
        script_dir.parent / "agentize.toml",
    ]
    for config_path in local_configs:
        if config_path.exists():
            try:
                with open(config_path, "rb") as f:
                    config = tomllib.load(f)
                if "container" in config and "runtime" in config["container"]:
                    return config["container"]["runtime"]
            except Exception:
                pass

    # Priority 2: Global config file
    config_path = Path.home() / ".config" / "agentize" / "agentize.toml"
    if config_path.exists():
        try:
            with open(config_path, "rb") as f:
                config = tomllib.load(f)
            if "container" in config and "runtime" in config["container"]:
                return config["container"]["runtime"]
        except Exception:
            pass

    # Priority 3: Environment variable
    runtime = os.environ.get("CONTAINER_RUNTIME")
    if runtime:
        return runtime

    # Priority 4: Auto-detection
    if shutil.which("podman"):
        return "podman"

    # Default to docker
    return "docker"


def get_host_architecture() -> str:
    """Map platform.machine() to standard architecture names."""
    arch = platform.machine().lower()

    # Normalize architecture names
    arch_map = {
        "x86_64": "amd64",
        "amd64": "amd64",
        "aarch64": "arm64",
        "arm64": "arm64",
        "armv8l": "arm64",
    }
    return arch_map.get(arch, arch)


def is_interactive() -> bool:
    """Check if running interactively (has TTY and not piping)."""
    return sys.stdin.isatty() and sys.stdout.isatty()


def calculate_files_hash(files: list[Path]) -> str:
    """Calculate a hash of the contents of the given files."""
    hasher = hashlib.sha256()
    for file_path in files:
        if file_path.exists():
            with open(file_path, "rb") as f:
                hasher.update(f.read())
    return hasher.hexdigest()


def get_image_hash() -> Optional[str]:
    """Get the cached image hash."""
    if CACHE_FILE.exists():
        try:
            with open(CACHE_FILE) as f:
                data = json.load(f)
            return data.get("hash")
        except Exception:
            pass
    return None


def save_image_hash(image_hash: str) -> None:
    """Save the image hash to cache."""
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    with open(CACHE_FILE, "w") as f:
        json.dump({"hash": image_hash}, f)


def image_exists(runtime: str, image_name: str) -> bool:
    """Check if the container image exists."""
    try:
        subprocess.run(
            [runtime, "image", "inspect", image_name],
            capture_output=True,
            check=True,
        )
        return True
    except subprocess.CalledProcessError:
        return False


def build_image(runtime: str, image_name: str, context: Path) -> bool:
    """Build the container image."""
    print(f"Building {image_name} with {runtime}...", file=sys.stderr)
    try:
        subprocess.run(
            [runtime, "build", "-t", image_name, str(context)],
            check=True,
        )
        return True
    except subprocess.CalledProcessError as e:
        print(f"Failed to build image: {e}", file=sys.stderr)
        return False


def ensure_image(runtime: str, context: Path) -> bool:
    """Ensure the container image exists and is up-to-date."""
    # Check if image exists
    if not image_exists(runtime, IMAGE_NAME):
        print(f"Image {IMAGE_NAME} not found, building...", file=sys.stderr)
        return build_image(runtime, IMAGE_NAME, context)

    # Calculate current hash of build trigger files
    trigger_paths = [context / f for f in BUILD_TRIGGER_FILES]
    current_hash = calculate_files_hash(trigger_paths)
    cached_hash = get_image_hash()

    if cached_hash != current_hash:
        print(f"Build files changed, rebuilding {IMAGE_NAME}...", file=sys.stderr)
        if build_image(runtime, IMAGE_NAME, context):
            save_image_hash(current_hash)
            return True
        return False

    return True


def parse_arguments(argv=None):
    """Parse command line arguments.

    Handles multiple argument patterns:
    - ./run.py -- --help                    -> container_args=['--help']
    - ./run.py --cmd bash                   -> custom_cmd=['bash']
    - ./run.py --cmd bash -c "echo hello"   -> custom_cmd=['bash', '-c', 'echo hello']
    - ./run.py my-container -- --help       -> container_name='my-container', container_args=['--help']
    """
    if argv is None:
        argv = sys.argv[1:]

    custom_cmd = []
    container_args = []

    # Extract custom_cmd (after --cmd) and container_args (after --)
    i = 0
    cmd_mode = False
    dash_dash_mode = False
    while i < len(argv):
        arg = argv[i]
        if arg == "--":
            dash_dash_mode = True
            i += 1
            continue
        if arg == "--cmd":
            cmd_mode = True
            i += 1
            continue

        if cmd_mode and not dash_dash_mode:
            custom_cmd.append(arg)
        elif dash_dash_mode:
            container_args.append(arg)
        i += 1

    # Build filtered argv for argparse (remove --cmd and everything after it, and --)
    # Remove --cmd and any args that were captured as custom_cmd
    filtered_argv = []
    skip_until_dash = False
    for arg in argv:
        if skip_until_dash:
            if arg == "--":
                skip_until_dash = False
            continue
        if arg == "--cmd":
            skip_until_dash = True
            continue
        if arg == "--":
            continue  # Don't include -- in filtered argv
        filtered_argv.append(arg)

    parser = argparse.ArgumentParser(
        description="Run agentize container with volume passthrough.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--cmd",
        action="store_true",
        help="Execute custom command instead of starting shell",
    )
    parser.add_argument(
        "--ccr",
        action="store_true",
        help="Run in CCR mode (claude-code-router)",
    )
    parser.add_argument(
        "--entrypoint",
        metavar="COMMAND",
        help="Override the default entrypoint",
    )
    parser.add_argument(
        "--build",
        action="store_true",
        help="Force rebuild of the container image",
    )
    parser.add_argument(
        "container_name",
        nargs="?",
        default="agentize_runner",
        help="Container name (default: agentize_runner)",
    )

    parsed = parser.parse_args(filtered_argv)

    # If custom_cmd was provided via --cmd, use it
    if custom_cmd:
        parsed.cmd = True

    return parsed, container_args, custom_cmd


def parse_container_args(argv):
    """Parse arguments after -- separator."""
    container_args = []
    custom_cmd = []
    seen_cmd = False

    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg == "--cmd":
            seen_cmd = True
            i += 1
            continue

        if seen_cmd:
            custom_cmd.append(arg)
        else:
            container_args.append(arg)
        i += 1

    return container_args, custom_cmd


def build_run_command(
    runtime: str,
    container_name: str,
    is_interactive: bool,
    use_ccr: bool,
    use_cmd: bool,
    custom_cmd: list[str],
    container_args: list[str],
    entrypoint: Optional[str],
) -> list[str]:
    """Build the container run command."""
    cmd = [runtime, "run", "--rm"]

    # Interactive mode detection
    if is_interactive:
        cmd.extend(["-it"])
    else:
        cmd.append("-t")

    # Container name
    cmd.extend(["--name", container_name])

    # Volume mounts
    home = Path.home()

    # 1. claude-code-router config (mounted to both config.json and config-router.json)
    ccr_config = home / ".claude-code-router" / "config.json"
    if ccr_config.exists():
        cmd.extend(["-v", f"{ccr_config}:/home/agentizer/.claude-code-router/config.json:ro"])
        cmd.extend(["-v", f"{ccr_config}:/home/agentizer/.claude-code-router/config-router.json:ro"])

    # 2. GitHub CLI credentials (mount individual files for proper permission handling)
    gh_config_yml = home / ".config" / "gh" / "config.yml"
    if gh_config_yml.exists():
        cmd.extend(["-v", f"{gh_config_yml}:/home/agentizer/.config/gh/config.yml:ro"])

    gh_hosts = home / ".config" / "gh" / "hosts.yml"
    if gh_hosts.exists():
        cmd.extend(["-v", f"{gh_hosts}:/home/agentizer/.config/gh/hosts.yml:ro"])

    # 3. Git credentials
    git_creds = home / ".git-credentials"
    if git_creds.exists():
        cmd.extend(["-v", f"{git_creds}:/home/agentizer/.git-credentials:ro"])

    git_config = home / ".gitconfig"
    if git_config.exists():
        cmd.extend(["-v", f"{git_config}:/home/agentizer/.gitconfig:ro"])

    # 4. Project directory
    script_dir = Path(__file__).parent.resolve()
    project_dir = script_dir.parent
    cmd.extend(["-v", f"{project_dir}:/workspace/agentize"])

    # 5. GitHub token
    if "GITHUB_TOKEN" in os.environ:
        cmd.extend(["-e", f"GITHUB_TOKEN={os.environ['GITHUB_TOKEN']}"])

    # 6. Working directory
    cmd.extend(["-w", "/workspace/agentize"])

    # Image name
    image_name = IMAGE_NAME

    # Handle entrypoint override
    if entrypoint:
        cmd.extend(["--entrypoint", entrypoint])

    # Handle custom command execution
    if use_cmd and custom_cmd:
        cmd.extend(["--entrypoint", "/bin/bash", image_name, "-c"])
        cmd.append(shlex.join(custom_cmd))
    elif use_ccr:
        cmd.extend(["--entrypoint", "/usr/local/bin/entrypoint", image_name, "--ccr"])
        cmd.extend(container_args)
    else:
        cmd.append(image_name)
        cmd.extend(container_args)

    return cmd


def main():
    """Main entry point."""
    args, container_args, custom_cmd = parse_arguments()

    # Determine container runtime
    runtime = get_container_runtime()
    print(f"Using container runtime: {runtime}", file=sys.stderr)

    # Get architecture (for informational purposes)
    arch = get_host_architecture()
    print(f"Detected host architecture: {arch}", file=sys.stderr)

    # Ensure image exists (with automatic rebuild detection)
    script_dir = Path(__file__).parent.resolve()
    if args.build:
        # Force rebuild
        if not build_image(runtime, IMAGE_NAME, script_dir):
            print("Failed to build container image", file=sys.stderr)
            sys.exit(1)
        # Update cache after rebuild
        trigger_paths = [script_dir / f for f in BUILD_TRIGGER_FILES]
        current_hash = calculate_files_hash(trigger_paths)
        save_image_hash(current_hash)
    elif not ensure_image(runtime, script_dir):
        print("Failed to ensure container image", file=sys.stderr)
        sys.exit(1)

    # Determine if running in interactive mode
    interactive = is_interactive()

    # If custom_cmd is provided via --cmd, use it (overrides container_args)
    use_cmd = args.cmd or bool(custom_cmd)

    # Build and execute command
    cmd = build_run_command(
        runtime=runtime,
        container_name=args.container_name,
        is_interactive=interactive,
        use_ccr=args.ccr,
        use_cmd=args.cmd or bool(custom_cmd),
        custom_cmd=custom_cmd,
        container_args=container_args,
        entrypoint=args.entrypoint,
    )

    # Execute
    os.execvp(cmd[0], cmd)


if __name__ == "__main__":
    main()