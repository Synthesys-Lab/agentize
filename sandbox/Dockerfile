# syntax=docker/dockerfile:1

# =============================================================================
# Agentize Development Sandbox
# =============================================================================
# A comprehensive development environment container for agentize SDK development
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Base
# -----------------------------------------------------------------------------
FROM ubuntu:24.04 AS base

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/root

# Install base packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    git \
    vim \
    unzip \
    zip \
    tar \
    build-essential \
    libssl-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Stage 2: Node.js
# -----------------------------------------------------------------------------
FROM base AS node

# Install NodeSource Node.js 20.x LTS
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get update && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Stage 3: Python & uv
# -----------------------------------------------------------------------------
FROM node AS python

# Install uv package manager
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && ln -sf /root/.local/bin/uv /usr/local/bin/uv

# Install Python and pip
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Stage 4: SDKMAN
# -----------------------------------------------------------------------------
FROM python AS sdkman

# Install SDKMAN
RUN curl -s "https://get.sdkman.io" | bash

# Configure shell profile for SDKMAN
RUN echo 'source "$HOME/.sdkman/bin/sdkman-init.sh"' >> /root/.bashrc

# -----------------------------------------------------------------------------
# Stage 5: Browser
# -----------------------------------------------------------------------------
FROM sdkman AS browser

# Playwright's bundled Chromium will be installed in tools stage
# No separate browser installation needed here

# -----------------------------------------------------------------------------
# Stage 6: Tools (claude-code-router, playwright-mcp)
# -----------------------------------------------------------------------------
FROM browser AS tools

# Install GitHub CLI from official binary release
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then \
        GH_ARCH="arm64"; \
    else \
        GH_ARCH="amd64"; \
    fi && \
    curl -fsSL https://github.com/cli/cli/releases/download/v2.55.0/gh_2.55.0_linux_${GH_ARCH}.tar.gz -o /tmp/gh.tar.gz && \
    tar -xzf /tmp/gh.tar.gz -C /tmp && \
    mv /tmp/gh_2.55.0_linux_${GH_ARCH}/bin/gh /usr/local/bin/ && \
    mv /tmp/gh_2.55.0_linux_${GH_ARCH}/bin/ghd /usr/local/bin/ 2>/dev/null || true && \
    rm -rf /tmp/gh.tar.gz /tmp/gh_2.55.0_linux_${GH_ARCH}

# Install claude-code-router globally
RUN npm install -g claude-code-router

# Install playwright and playwright MCP with bundled Chromium
RUN npm install -g playwright \
    && npx playwright install --with-deps chromium

# Create symlinks for browser compatibility (playwright's bundled chromium)
RUN ln -sf /root/.cache/ms-playwright/chromium-*/chrome-linux/chrome /usr/bin/google-chrome 2>/dev/null || true && \
    ln -sf /root/.cache/ms-playwright/chromium-*/chrome-linux/chrome /usr/bin/chromium 2>/dev/null || true

# -----------------------------------------------------------------------------
# Stage 7: Claude Code
# -----------------------------------------------------------------------------
FROM tools AS claude

# Copy Claude Code install script
COPY install.sh /tmp/install.sh

# Create required directories
RUN mkdir -p /root/.claude/downloads

# Install Claude Code (silent mode - assumes install.sh works in container)
RUN chmod +x /tmp/install.sh \
    && /tmp/install.sh stable \
    && rm -f /tmp/install.sh \
    && rm -f /usr/local/bin/claude \
    && cp /root/.local/bin/claude /usr/local/bin/claude && chmod +x /usr/local/bin/claude

# -----------------------------------------------------------------------------
# Stage 8: Final
# -----------------------------------------------------------------------------
FROM claude AS final

# Create sudoers.d directory for non-root sudo access
RUN mkdir -p /etc/sudoers.d \
    && echo "agentizer ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/agentizer \
    && chmod 440 /etc/sudoers.d/agentizer

# Add non-root user
RUN useradd -m -s /bin/bash agentizer \
    && mkdir -p /home/agentizer/.claude/downloads \
    && chown -R agentizer:agentizer /home/agentizer

# Copy SDKMAN installation from root to agentizer home
RUN cp -r /root/.sdkman /home/agentizer/.sdkman \
    && chown -R agentizer:agentizer /home/agentizer/.sdkman

# Set working directory
WORKDIR /workspace

# Set environment for agentizer
ENV HOME=/home/agentizer

# Configure PATH and SDKMAN for agentizer user
RUN echo 'export PATH="/usr/local/bin:$PATH"' >> /home/agentizer/.bashrc \
    && echo 'source "$HOME/.sdkman/bin/sdkman-init.sh"' >> /home/agentizer/.bashrc

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint
RUN chmod +x /usr/local/bin/entrypoint

# Switch to non-root user
USER agentizer

# Default command
ENTRYPOINT ["/usr/local/bin/entrypoint"]
CMD ["/bin/bash"]