#!/bin/bash

# Digital Twin System - Unified Startup Script
# Single point of entry for the entire system
# Supports both Docker and Local deployment modes

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

clear

echo "==========================================================="
echo "   GridTwin - Substation Digital Twin Platform"
echo "   Real-time Monitoring & AI/ML Analytics"
echo "==========================================================="
echo ""

# Deployment mode: docker, local, or auto (default)
MODE="${1:-auto}"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if port is in use
check_port() {
    if lsof -ti:$1 >/dev/null 2>&1; then
        echo -e "${YELLOW}Port $1 is in use. Killing existing process...${NC}"
        lsof -ti:$1 | xargs kill -9 2>/dev/null || true
        sleep 1
    fi
}

# Load environment configuration
load_env() {
    if [ -f .env ]; then
        echo -e "${BLUE}Loading environment configuration...${NC}"
        set -a
        source .env
        set +a
        echo -e "${GREEN}✓ Environment loaded${NC}"
    fi
}

# Function to start with Docker
start_docker() {
    echo -e "${BLUE}Starting with Docker Compose...${NC}"

    # Check Docker installation
    if ! command_exists docker; then
        echo -e "${RED}Docker is not installed. Install from: https://docs.docker.com/get-docker/${NC}"
        exit 1
    fi

    if ! command_exists docker-compose; then
        echo -e "${RED}Docker Compose is not installed. Install from: https://docs.docker.com/compose/install/${NC}"
        exit 1
    fi

    # Load environment
    load_env

    # Build and start services
    echo -e "${BLUE}Building Docker images...${NC}"
    docker-compose build

    echo -e "${BLUE}Starting Docker services...${NC}"
    docker-compose up -d backend frontend redis influxdb

    echo -e "${GREEN}✓ Docker services started!${NC}"
    docker-compose ps

    # Wait for services to be healthy
    echo ""
    echo -e "${YELLOW}Waiting for services to be ready...${NC}"
    sleep 5

    # Display success message
    echo ""
    echo "==========================================================="
    echo -e "${GREEN} Digital Twin System Successfully Started!${NC}"
    echo "==========================================================="
    echo ""
    echo "Access Points:"
    echo "  • Frontend:    http://localhost:3000"
    echo "  • Backend API: http://localhost:8000"
    echo "  • API Docs:    http://localhost:8000/docs"
    echo "  • InfluxDB:    http://localhost:8086"
    echo "  • DSS Editor:  http://localhost:3000/dss-editor"
    echo ""
    echo "To stop all services: docker-compose down"
    echo ""
    echo -e "${BLUE}==================== Backend Logs ====================${NC}"
    echo -e "${YELLOW}Showing live backend logs (Ctrl+C to exit, services will keep running)${NC}"
    echo ""
    sleep 2
    docker-compose logs -f backend
}

# Function to start locally
start_local() {
    # Load environment
    load_env

    # Step 0: Start database containers (optional)
    echo -e "${BLUE}[0/6] Checking database containers...${NC}"
    if command_exists docker && docker info >/dev/null 2>&1; then
        # Docker is available and running
        docker compose up -d redis influxdb 2>/dev/null || docker-compose up -d redis influxdb 2>/dev/null || true

        # Wait for databases to be ready
        echo -e "${YELLOW}Waiting for databases to be ready...${NC}"
        sleep 3

        # Check if containers are running
        if docker ps | grep -q -E "redis"; then
            echo -e "${GREEN}✓ Redis running${NC}"
        fi

        if docker ps | grep -q "influxdb"; then
            echo -e "${GREEN}✓ InfluxDB running${NC}"
        fi
    else
        echo -e "${YELLOW}Docker not available or not running - using local SQLite databases${NC}"
        echo -e "${YELLOW}(This is fine - system will work with SQLite)${NC}"
    fi

    # Step 1: Check Python environment
    echo -e "${BLUE}[1/5] Checking Python environment...${NC}"
    if [ -d "venv" ]; then
        # Check if virtual environment is corrupted
        if ! source venv/bin/activate 2>/dev/null || ! python -c "import sys" 2>/dev/null; then
            echo -e "${YELLOW}Virtual environment corrupted, recreating...${NC}"
            rm -rf venv
            python3 -m venv venv
            source venv/bin/activate
        else
            source venv/bin/activate
            echo -e "${GREEN}✓ Virtual environment activated${NC}"
        fi
    else
        echo -e "${YELLOW}Creating virtual environment...${NC}"
        python3 -m venv venv
        source venv/bin/activate
    fi

    # Step 2: Install dependencies
    echo -e "${BLUE}[2/5] Installing dependencies...${NC}"
    # Fix pip if corrupted
    if ! pip --version >/dev/null 2>&1; then
        echo -e "${YELLOW}Fixing pip installation...${NC}"
        python -m ensurepip --upgrade 2>/dev/null || true
        python -m pip install --upgrade pip --force-reinstall 2>/dev/null || true
    fi
    
    # Install from requirements.txt if available, otherwise install minimal dependencies
    if [ -f "requirements.txt" ]; then
        pip install -r requirements.txt
    else
        pip install fastapi uvicorn websockets pandas numpy scikit-learn matplotlib \
            httpx python-multipart aiofiles pymodbus python-dotenv
    fi
    echo -e "${GREEN}✓ Dependencies installed${NC}"

    # Step 3: Train AI models if needed
    echo -e "${BLUE}[3/6] Checking AI/ML models...${NC}"
    if [ ! -d "models" ] || [ ! -f "models/anomaly_detector.pkl" ]; then
        echo -e "${YELLOW}Training AI/ML models (first-time setup, ~30 seconds)...${NC}"
        python train_ai_models.py > logs/training.log 2>&1
        echo -e "${GREEN}✓ AI models trained${NC}"
    else
        echo -e "${GREEN}✓ Pre-trained models found${NC}"
    fi

    # Step 4: Clean up existing processes
    echo -e "${BLUE}[4/6] Preparing system...${NC}"
    check_port 8000
    check_port 3000
    echo -e "${GREEN}✓ System ready${NC}"

    # Step 5: Start backend
    echo -e "${BLUE}[5/6] Starting backend server...${NC}"
    
    # Try different backend startup methods
    if [ -f "src/backend_server.py" ]; then
        python src/backend_server.py > logs/backend.log 2>&1 &
        BACKEND_PID=$!
    elif [ -f "main.py" ]; then
        python main.py > logs/backend.log 2>&1 &
        BACKEND_PID=$!
    else
        echo -e "${RED}No backend server file found${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Backend started (PID: $BACKEND_PID)${NC}"

    # Wait for backend
    echo -e "${YELLOW}Waiting for backend to be ready...${NC}"
    for i in {1..30}; do
        if curl -s http://localhost:8000/health >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Backend is healthy${NC}"
            break
        fi
        sleep 1
    done

    # Final health check
    if ! curl -s http://localhost:8000/health >/dev/null 2>&1; then
        echo -e "${RED}✗ Backend failed to start. Check logs/backend.log${NC}"
        exit 1
    fi

    # Step 6: Start frontend (if exists)
    if [ -d "frontend" ] && [ -f "frontend/package.json" ]; then
        echo -e "${BLUE}[6/6] Starting frontend...${NC}"
        cd frontend
        if [ ! -d "node_modules" ]; then
            npm install --silent
        fi
        DANGEROUSLY_DISABLE_HOST_CHECK=true npm start > ../logs/frontend.log 2>&1 &
        FRONTEND_PID=$!
        cd ..
        echo -e "${GREEN}✓ Frontend started (PID: $FRONTEND_PID)${NC}"
    else
        echo -e "${YELLOW}Frontend not configured, running backend only${NC}"
    fi

    # Display success message
    echo ""
    echo "==========================================================="
    echo -e "${GREEN} Digital Twin System Successfully Started!${NC}"
    echo "==========================================================="
    echo ""
    echo "Access Points:"
    echo "  • Frontend:    http://localhost:3000"
    echo "  • Backend API: http://localhost:8000"
    echo "  • API Docs:    http://localhost:8000/docs"
    echo "  • DSS Editor:  http://localhost:3000/dss-editor"
    echo ""
    echo "Backend PID: $BACKEND_PID"
    [ ! -z "$FRONTEND_PID" ] && echo "Frontend PID: $FRONTEND_PID"
    echo ""
    echo "To stop: Press Ctrl+C or run: kill $BACKEND_PID"
    echo ""
    echo -e "${BLUE}==================== Backend Logs ====================${NC}"
    echo -e "${YELLOW}Showing live backend logs (Ctrl+C to exit, services will keep running)${NC}"
    echo ""
    sleep 1
    tail -f logs/backend.log
}

# Create logs directory if not exists
mkdir -p logs

# Main execution based on mode
case "$MODE" in
    docker)
        start_docker
        ;;
    local)
        start_local
        ;;
    auto|*)
        # Auto-detect mode
        if command_exists docker && command_exists docker-compose && [ -f "docker-compose.yml" ]; then
            echo -e "${BLUE}Docker detected. Choose deployment mode:${NC}"
            echo "  1) Docker (recommended for production)"
            echo "  2) Local (for development)"
            echo ""
            read -p "Enter choice [1-2] (default: 2): " choice
            case $choice in
                1) start_docker ;;
                *) start_local ;;
            esac
        else
            start_local
        fi
        ;;
esac

# Cleanup on exit
cleanup() {
    echo ""
    echo -e "${YELLOW}Shutting down Digital Twin...${NC}"
    if [ "$MODE" = "docker" ] || [ "$MODE" = "1" ]; then
        echo -e "${BLUE}Stopping Docker containers...${NC}"
        docker-compose down
    else
        [ ! -z "$BACKEND_PID" ] && kill $BACKEND_PID 2>/dev/null || true
        [ ! -z "$FRONTEND_PID" ] && kill $FRONTEND_PID 2>/dev/null || true
        deactivate 2>/dev/null || true
    fi
    echo -e "${GREEN}System stopped${NC}"
    exit 0
}

trap cleanup SIGINT SIGTERM

# Note: Logs are now being tailed in the start_docker() or start_local() functions
# The script will continue running until user presses Ctrl+C