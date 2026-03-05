#!/usr/bin/env bash
set -euo pipefail

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1" >&2; }
ask()  { echo -en "${BLUE}[?]${NC} $1"; }

CLAWAPP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENCLAW_CONFIG="$HOME/.openclaw/openclaw.json"

# ── Step 1: Prerequisites ──────────────────────────────────────────────────

check_os() {
    if [[ ! -f /etc/os-release ]]; then
        err "Cannot detect OS. This script supports Ubuntu/Debian."
        exit 1
    fi
    source /etc/os-release
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" && "$ID_LIKE" != *"debian"* ]]; then
        warn "This script is designed for Ubuntu/Debian. Proceeding anyway..."
    fi
    log "OS: $PRETTY_NAME"
}

install_docker() {
    if command -v docker &>/dev/null; then
        log "Docker already installed: $(docker --version | head -1)"
        return
    fi

    log "Installing Docker..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq docker.io docker-compose-plugin >/dev/null 2>&1
    sudo usermod -aG docker "$USER"
    warn "Added $USER to docker group. You may need to log out and back in."
    log "Docker installed"
}

install_node() {
    if command -v node &>/dev/null; then
        NODE_VERSION=$(node --version | sed 's/v//' | cut -d. -f1)
        if [[ "$NODE_VERSION" -ge 18 ]]; then
            log "Node.js already installed: $(node --version)"
            return
        fi
    fi

    log "Installing Node.js 22..."
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - >/dev/null 2>&1
    sudo apt-get install -y -qq nodejs >/dev/null 2>&1
    log "Node.js installed: $(node --version)"
}

check_ports() {
    local failed=0
    for port in 8080 18789; do
        if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
            warn "Port $port is already in use"
            failed=1
        fi
    done
    if [[ $failed -eq 1 ]]; then
        ask "Ports in use. Continue anyway? (y/N) "
        read -r reply
        [[ "$reply" =~ ^[Yy] ]] || exit 1
    fi
}

# ── Step 2: OpenClaw ──────────────────────────────────────────────────────

install_openclaw() {
    if command -v openclaw &>/dev/null; then
        log "OpenClaw already installed: $(openclaw --version 2>&1 | head -1)"
    else
        log "Installing OpenClaw..."
        npm install -g openclaw >/dev/null 2>&1
        log "OpenClaw installed: $(openclaw --version 2>&1 | head -1)"
    fi
}

configure_openclaw() {
    # Generate gateway auth token
    GATEWAY_TOKEN=$(openssl rand -hex 24)

    if [[ -f "$OPENCLAW_CONFIG" ]]; then
        warn "OpenClaw config already exists at $OPENCLAW_CONFIG"
        ask "Overwrite? (y/N) "
        read -r reply
        if [[ ! "$reply" =~ ^[Yy] ]]; then
            # Read existing token from config
            GATEWAY_TOKEN=$(python3 -c "
import json
with open('$OPENCLAW_CONFIG') as f:
    c = json.load(f)
print(c.get('gateway',{}).get('auth',{}).get('token',''))
" 2>/dev/null || echo "$GATEWAY_TOKEN")
            log "Keeping existing config (gateway token: ${GATEWAY_TOKEN:0:12}...)"
            return
        fi
    fi

    mkdir -p "$HOME/.openclaw"

    cat > "$OPENCLAW_CONFIG" << OCEOF
{
  "gateway": {
    "port": 18789,
    "bind": "lan",
    "auth": {
      "mode": "token",
      "token": "$GATEWAY_TOKEN"
    },
    "controlUi": {
      "allowedOrigins": [
        "http://localhost:18789",
        "http://127.0.0.1:18789",
        "http://172.0.0.0/8",
        "http://host.docker.internal:18789"
      ]
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "anthropic/claude-sonnet-4-5"
      }
    }
  }
}
OCEOF

    log "OpenClaw config written to $OPENCLAW_CONFIG"

    # Anthropic auth token
    echo ""
    echo -e "${BOLD}ClawApp uses Claude as its AI backend.${NC}"
    echo "You need a Claude authentication token from your Anthropic account."
    echo ""
    echo "To get your token:"
    echo "  1. Go to https://console.anthropic.com"
    echo "  2. Create an API key"
    echo "  3. Copy the key (starts with sk-ant-...)"
    echo ""
    ask "Paste your Anthropic API key: "
    read -r ANTHROPIC_KEY

    if [[ -n "$ANTHROPIC_KEY" ]]; then
        mkdir -p "$HOME/.openclaw/agents/main/agent"
        cat > "$HOME/.openclaw/agents/main/agent/auth-profiles.json" << AUTHEOF
{
  "activeProfile": "anthropic:manual",
  "profiles": {
    "anthropic:manual": {
      "provider": "anthropic",
      "type": "manual",
      "key": "$ANTHROPIC_KEY"
    }
  }
}
AUTHEOF
        log "Anthropic auth token saved"
    else
        warn "No API key provided — Maddie will send stub responses until configured."
    fi
}

start_openclaw() {
    # Use OpenClaw's built-in service installer
    log "Installing OpenClaw gateway service..."
    openclaw gateway install --bind lan --auth token 2>/dev/null || true
    openclaw gateway start 2>/dev/null || true

    # Wait for gateway to be reachable
    local retries=10
    while [[ $retries -gt 0 ]]; do
        if openclaw status 2>&1 | grep -qi "running\|listening\|ok"; then
            log "OpenClaw gateway is running"
            return
        fi
        sleep 2
        retries=$((retries - 1))
    done
    warn "OpenClaw gateway may not be running yet. Check: openclaw status"
}

# ── Step 3: ClawApp Server ────────────────────────────────────────────────

deploy_clawapp() {
    cd "$CLAWAPP_DIR"

    # Check for required files
    if [[ ! -f "Dockerfile" || ! -d "ClawAppServer" ]]; then
        err "Missing Dockerfile or ClawAppServer directory."
        err "Run this script from the clawapp repository root."
        exit 1
    fi

    # Generate docker-compose.yml
    cat > docker-compose.yml << DCEOF
services:
  clawapp:
    build: .
    ports:
      - "8080:8080"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    environment:
      - DATABASE_URL=postgres://clawapp:clawapp@db:5432/clawapp
      - OPENCLAW_URL=http://host.docker.internal:18789
      - OPENCLAW_TOKEN=${GATEWAY_TOKEN}
      - DATA_DIR=/data
    volumes:
      - app_data:/data
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped

  db:
    image: postgres:16-alpine
    environment:
      - POSTGRES_DB=clawapp
      - POSTGRES_USER=clawapp
      - POSTGRES_PASSWORD=clawapp
    volumes:
      - pg_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U clawapp"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  pg_data:
  app_data:
DCEOF

    log "docker-compose.yml generated"

    # Build and start
    echo ""
    log "Building ClawApp server (this takes ~8 minutes on first run)..."
    docker compose up -d --build 2>&1 | tail -5

    # Wait for server to be healthy
    log "Waiting for server to start..."
    local retries=30
    while [[ $retries -gt 0 ]]; do
        if curl -sf http://localhost:8080/api/v1/health >/dev/null 2>&1; then
            log "ClawApp server is running"
            break
        fi
        sleep 2
        retries=$((retries - 1))
    done

    if [[ $retries -eq 0 ]]; then
        err "Server did not start. Check: docker compose logs clawapp"
        exit 1
    fi

    # Extract API token from logs
    API_TOKEN=$(docker compose logs clawapp 2>&1 | grep -oP 'clw_[a-f0-9]+' | head -1)
    if [[ -z "$API_TOKEN" ]]; then
        # Try reading from the volume
        API_TOKEN=$(docker compose exec clawapp cat /data/.clawapp-token 2>/dev/null || echo "")
    fi

    if [[ -z "$API_TOKEN" ]]; then
        warn "Could not extract API token. Check: docker compose logs clawapp"
    else
        log "API token: ${API_TOKEN:0:20}..."
    fi
}

# ── Step 4: Cloudflare Tunnel ─────────────────────────────────────────────

setup_tunnel() {
    echo ""
    echo -e "${BOLD}Public URL Setup${NC}"
    echo "To access ClawApp from anywhere, you can set up a Cloudflare Tunnel."
    echo "This gives you a public HTTPS URL (e.g., clawapp.yourdomain.com)."
    echo ""
    ask "Set up a Cloudflare Tunnel? (y/N) "
    read -r reply

    if [[ ! "$reply" =~ ^[Yy] ]]; then
        LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
        SERVER_URL="http://${LOCAL_IP}:8080"
        warn "Skipping tunnel. Server available at $SERVER_URL (local network only)."
        echo "  For remote access, consider Tailscale: https://tailscale.com"
        return
    fi

    # Install cloudflared if needed
    if ! command -v cloudflared &>/dev/null; then
        log "Installing cloudflared..."
        curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o /tmp/cloudflared.deb
        sudo dpkg -i /tmp/cloudflared.deb >/dev/null 2>&1
        rm /tmp/cloudflared.deb
        log "cloudflared installed"
    else
        log "cloudflared already installed"
    fi

    # Login to Cloudflare (opens browser)
    if [[ ! -f "$HOME/.cloudflared/cert.pem" ]]; then
        echo ""
        echo "A browser window will open to authenticate with Cloudflare."
        echo "If you're on a headless server, copy the URL and open it on any device."
        echo ""
        cloudflared tunnel login
    fi

    # Create tunnel
    TUNNEL_NAME="clawapp-$(hostname -s)"
    if cloudflared tunnel list 2>/dev/null | grep -q "$TUNNEL_NAME"; then
        log "Tunnel '$TUNNEL_NAME' already exists"
        TUNNEL_ID=$(cloudflared tunnel list 2>/dev/null | grep "$TUNNEL_NAME" | awk '{print $1}')
    else
        log "Creating tunnel '$TUNNEL_NAME'..."
        cloudflared tunnel create "$TUNNEL_NAME"
        TUNNEL_ID=$(cloudflared tunnel list 2>/dev/null | grep "$TUNNEL_NAME" | awk '{print $1}')
    fi

    # Get domain from user
    echo ""
    ask "Enter the hostname for your server (e.g., clawapp.yourdomain.com): "
    read -r CLAWAPP_HOSTNAME

    if [[ -z "$CLAWAPP_HOSTNAME" ]]; then
        warn "No hostname provided. Skipping DNS routing."
        LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
        SERVER_URL="http://${LOCAL_IP}:8080"
        return
    fi

    # Route DNS
    cloudflared tunnel route dns "$TUNNEL_NAME" "$CLAWAPP_HOSTNAME" 2>/dev/null || \
        cloudflared tunnel route dns -f "$TUNNEL_NAME" "$CLAWAPP_HOSTNAME" 2>/dev/null || true
    log "DNS routed: $CLAWAPP_HOSTNAME -> tunnel"

    SERVER_URL="https://$CLAWAPP_HOSTNAME"

    # Find credentials file
    CREDS_FILE=$(find "$HOME/.cloudflared" -name "${TUNNEL_ID}.json" 2>/dev/null | head -1)
    if [[ -z "$CREDS_FILE" ]]; then
        CREDS_FILE="$HOME/.cloudflared/${TUNNEL_ID}.json"
    fi

    # Generate cloudflared config
    sudo mkdir -p /etc/cloudflared
    sudo tee /etc/cloudflared/config.yml > /dev/null << CFEOF
tunnel: ${TUNNEL_ID}
credentials-file: ${CREDS_FILE}

ingress:
  - hostname: ${CLAWAPP_HOSTNAME}
    service: http://localhost:8080
  - service: http_status:404
CFEOF

    # Copy credentials to /etc/cloudflared if needed
    if [[ -f "$CREDS_FILE" ]]; then
        sudo cp "$CREDS_FILE" /etc/cloudflared/ 2>/dev/null || true
    fi

    # Install and start as system service
    sudo cloudflared service install 2>/dev/null || true
    sudo systemctl enable cloudflared 2>/dev/null || true
    sudo systemctl restart cloudflared 2>/dev/null || true

    log "Cloudflare Tunnel running: $SERVER_URL"
}

# ── Step 5: Print Connection Details ──────────────────────────────────────

print_connection_details() {
    echo ""
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║              ClawApp Setup Complete!                     ║${NC}"
    echo -e "${BOLD}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BOLD}║${NC}                                                          ${BOLD}║${NC}"
    echo -e "${BOLD}║${NC}  ${GREEN}Server URL:${NC}  ${SERVER_URL:-http://localhost:8080}"
    echo -e "${BOLD}║${NC}  ${GREEN}API Token:${NC}   ${API_TOKEN:-check docker compose logs clawapp}"
    echo -e "${BOLD}║${NC}                                                          ${BOLD}║${NC}"
    echo -e "${BOLD}║${NC}  Open ClawApp on your iPhone:                            ${BOLD}║${NC}"
    echo -e "${BOLD}║${NC}    1. Enter the Server URL above                         ${BOLD}║${NC}"
    echo -e "${BOLD}║${NC}    2. Paste the API Token                                ${BOLD}║${NC}"
    echo -e "${BOLD}║${NC}    3. Tap Connect                                        ${BOLD}║${NC}"
    echo -e "${BOLD}║${NC}                                                          ${BOLD}║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Useful commands:"
    echo "  openclaw status              # Check OpenClaw gateway"
    echo "  openclaw logs                # View AI logs"
    echo "  docker compose logs clawapp  # View server logs"
    echo "  docker compose restart       # Restart server"
    echo ""
}

# ── Main ──────────────────────────────────────────────────────────────────

main() {
    echo ""
    echo -e "${BOLD}ClawApp Self-Hosted Setup${NC}"
    echo "This will install and configure everything you need."
    echo ""

    # Initialize variables
    API_TOKEN=""
    SERVER_URL=""
    GATEWAY_TOKEN=""

    check_os
    check_ports
    install_docker
    install_node
    install_openclaw
    configure_openclaw
    start_openclaw
    deploy_clawapp
    setup_tunnel
    print_connection_details
}

main "$@"
