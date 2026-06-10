#!/usr/bin/env bash
set -euo pipefail

# ============================================================
#  TriageFlow — One-Command Project Setup
# ============================================================
#
# Clones the backend and frontend repos, starts Docker
# containers, configures the environment, runs migrations,
# and installs frontend dependencies. Everything except
# the OpenRouter API key is automated.
#
# Usage:
#   ./bin/setup.sh
#
# Prerequisites:
#   - Docker + Docker Compose v2
#   - Node.js 20+
#   - Git
# ============================================================

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS_ROOT="$(dirname "$SCRIPT_DIR")"
WORKSPACE_ROOT="$(dirname "$DOCS_ROOT")"
BACKEND_DIR="$WORKSPACE_ROOT/triageflow-backend"
FRONTEND_DIR="$WORKSPACE_ROOT/triageflow-frontend"

echo ""
echo "============================================"
echo "  TriageFlow — Project Setup"
echo "============================================"
echo ""
echo "Workspace: $WORKSPACE_ROOT"
echo ""

# --------------------------------------------------
# 1. Check prerequisites
# --------------------------------------------------
info "Checking prerequisites..."

if ! command -v git &>/dev/null; then
    error "Git not found. Install Git first."
    exit 1
fi
success "Git found"

if ! command -v docker &>/dev/null; then
    error "Docker not found. Install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi
success "Docker found"

if ! docker compose version &>/dev/null; then
    error "Docker Compose v2 not found."
    exit 1
fi
success "Docker Compose found"

if ! docker info &>/dev/null; then
    error "Docker daemon not running. Start Docker and try again."
    exit 1
fi
success "Docker daemon running"

if ! command -v node &>/dev/null; then
    error "Node.js not found. Install Node.js 20+: https://nodejs.org/"
    exit 1
fi
NODE_MAJOR=$(node -v | sed 's/v//' | cut -d. -f1)
if [ "$NODE_MAJOR" -lt 20 ]; then
    error "Node.js 20+ required, found v$(node -v)"
    exit 1
fi
success "Node.js $(node -v)"

if ! command -v npm &>/dev/null; then
    error "npm not found."
    exit 1
fi
success "npm $(npm -v)"

# --------------------------------------------------
# 2. Clone or pull repos
# --------------------------------------------------
echo ""
info "Setting up repositories..."

clone_or_pull() {
    local name="$1"
    local url="$2"
    local dir="$3"

    if [ -d "$dir/.git" ]; then
        info "Updating $name ..."
        cd "$dir"
        # Determine default branch
        local branch
        branch=$(git remote show origin 2>/dev/null | sed -n '/HEAD branch/s/.*: //p')
        branch="${branch:-master}"
        git fetch origin "$branch"
        git checkout "$branch"
        git pull origin "$branch"
        cd "$WORKSPACE_ROOT"
        success "$name updated"
    else
        info "Cloning $name ..."
        git clone "$url" "$dir"
        success "$name cloned"
    fi
}

clone_or_pull "triageflow-backend" \
    "https://github.com/psswid/triageflow-backend.git" \
    "$BACKEND_DIR"

clone_or_pull "triageflow-frontend" \
    "https://github.com/psswid/triageflow-frontend.git" \
    "$FRONTEND_DIR"

# --------------------------------------------------
# 3. Backend — Docker + config
# --------------------------------------------------
echo ""
info "Starting backend services..."

cd "$BACKEND_DIR"

# Create empty JWT key files so the Docker build's chmod doesn't fail
mkdir -p config/jwt
touch config/jwt/private.pem config/jwt/public.pem

# Build and start containers
docker compose up -d --build 2>&1
success "Docker containers started"

# Wait for PostgreSQL to be healthy
info "Waiting for PostgreSQL to be ready ..."
MAX_RETRIES=30
RETRY_COUNT=0
until docker compose exec -T db pg_isready -U triageflow &>/dev/null; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
        error "PostgreSQL did not start within ${MAX_RETRIES}s."
        error "Check logs: cd $BACKEND_DIR && docker compose logs db"
        exit 1
    fi
    sleep 2
done
success "PostgreSQL is ready"

# Generate random secrets
APP_SECRET=$(openssl rand -hex 32 2>/dev/null || date +%s%N | sha256sum | cut -d' ' -f1)
JWT_PASSPHRASE=$(openssl rand -hex 32 2>/dev/null || date +%s%N | sha256sum | cut -d' ' -f1)

# Create .env.local (gitignored, overrides .env for local development)
cat > "$BACKEND_DIR/.env.local" << ENVEOF
###> override for local development ###
APP_ENV=dev
APP_SECRET=${APP_SECRET}
JWT_PASSPHRASE=${JWT_PASSPHRASE}
###< override ###

###> openrouter (set your real key here) ###
OPENROUTER_API_KEY=sk-or-v1-your-key-here
###< openrouter ###
ENVEOF
success ".env.local created"

# Generate JWT key pair
info "Generating JWT keys ..."
docker compose exec -T php php bin/console lexik:jwt:generate-keypair --no-interaction 2>&1
success "JWT keys generated"

# Run database migrations
info "Running database migrations ..."
docker compose exec -T php php bin/console doctrine:migrations:migrate --no-interaction 2>&1
success "Database migrations complete"

# --------------------------------------------------
# 4. Frontend — npm + env
# --------------------------------------------------
echo ""
info "Setting up frontend..."

cd "$FRONTEND_DIR"

if [ ! -d "node_modules" ]; then
    info "Installing npm dependencies ..."
    npm install 2>&1
    success "npm dependencies installed"
else
    info "node_modules exists, running npm install for updates ..."
    npm install 2>&1
    success "npm dependencies up to date"
fi

# Create .env if it doesn't exist
if [ ! -f ".env" ]; then
    echo 'VITE_API_URL=http://localhost:8000' > .env
    success "Frontend .env created"
else
    success "Frontend .env already exists"
fi

# --------------------------------------------------
# 5. Summary
# --------------------------------------------------
echo ""
echo "============================================"
echo -e "  ${GREEN}TriageFlow Setup Complete!${NC}"
echo "============================================"
echo ""
echo -e "${YELLOW}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║  ACTION REQUIRED: Set your OpenRouter API Key  ║${NC}"
echo -e "${YELLOW}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo "  1. Edit this file:"
echo "     $BACKEND_DIR/.env.local"
echo ""
echo "  2. Change this line:"
echo "     OPENROUTER_API_KEY=sk-or-v1-your-key-here"
echo ""
echo "     To your real key (get one free at https://openrouter.ai/keys):"
echo "     OPENROUTER_API_KEY=sk-or-v1-actual-key-here"
echo ""
echo "  3. Restart the PHP container:"
echo "     cd $BACKEND_DIR && docker compose restart php"
echo ""
echo "============================================"
echo "  Access the Application"
echo "============================================"
echo ""
echo "  Frontend : http://localhost:5173"
echo "  Backend  : http://localhost:8000/health"
echo ""
echo "============================================"
echo "  Quick Commands"
echo "============================================"
echo ""
echo "  Backend tests : php bin/phpunit"
echo "  Frontend tests: npm test"
echo "  View logs     : docker compose logs -f"
echo "  Stop all      : docker compose down"
echo ""
