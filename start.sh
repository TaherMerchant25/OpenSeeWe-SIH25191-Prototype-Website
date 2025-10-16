#!/bin/bash

# OpenSeeWe - Smart Grid Digital Twin Platform
# Complete System Startup Script

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}$1${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check system requirements
check_requirements() {
    print_header "🔍 Checking System Requirements..."
    
    # Check Python
    if command_exists python3; then
        PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
        print_status "Python found: $PYTHON_VERSION"
    else
        print_error "Python 3.8+ is required but not found"
        exit 1
    fi
    
    # Check Node.js
    if command_exists node; then
        NODE_VERSION=$(node --version)
        print_status "Node.js found: $NODE_VERSION"
    else
        print_error "Node.js 16+ is required but not found"
        exit 1
    fi
    
    # Check npm
    if command_exists npm; then
        NPM_VERSION=$(npm --version)
        print_status "npm found: $NPM_VERSION"
    else
        print_error "npm is required but not found"
        exit 1
    fi
    
    print_status "✅ All requirements satisfied"
}

# Function to install Python dependencies
install_python_deps() {
    print_header "📦 Installing Python Dependencies..."
    
    if [ -f "requirements.txt" ]; then
        print_status "Installing Python packages..."
        pip install -r requirements.txt
        print_status "✅ Python dependencies installed"
    else
        print_warning "requirements.txt not found"
    fi
}

# Function to install frontend dependencies
install_frontend_deps() {
    print_header "📦 Installing Frontend Dependencies..."
    
    if [ -d "frontend" ]; then
        cd frontend
        print_status "Installing Node.js packages..."
        npm install
        cd ..
        print_status "✅ Frontend dependencies installed"
    else
        print_warning "Frontend directory not found"
    fi
}

# Function to train AI models
train_ai_models() {
    print_header "🧠 Training AI/ML Models..."
    
    if [ -f "train_ai_models.py" ]; then
        print_status "Training AI models with synthetic data..."
        python3 train_ai_models.py
        print_status "✅ AI models trained successfully"
    else
        print_warning "train_ai_models.py not found, skipping AI training"
    fi
}

# Function to start backend
start_backend() {
    print_header "🚀 Starting Backend Server..."
    
    if [ -f "main.py" ]; then
        print_status "Starting FastAPI backend..."
        python3 main.py &
        BACKEND_PID=$!
        sleep 3
        
        # Check if backend is running
        if kill -0 $BACKEND_PID 2>/dev/null; then
            print_status "✅ Backend started successfully (PID: $BACKEND_PID)"
            echo $BACKEND_PID > .backend.pid
        else
            print_error "Failed to start backend"
            exit 1
        fi
    else
        print_error "main.py not found"
        exit 1
    fi
}

# Function to start frontend
start_frontend() {
    print_header "🌐 Starting Frontend Server..."
    
    if [ -d "frontend" ]; then
        cd frontend
        print_status "Starting React development server..."
        npm start &
        FRONTEND_PID=$!
        cd ..
        sleep 5
        
        # Check if frontend is running
        if kill -0 $FRONTEND_PID 2>/dev/null; then
            print_status "✅ Frontend started successfully (PID: $FRONTEND_PID)"
            echo $FRONTEND_PID > .frontend.pid
        else
            print_error "Failed to start frontend"
            exit 1
        fi
    else
        print_error "Frontend directory not found"
        exit 1
    fi
}

# Function to verify system health
verify_system() {
    print_header "🔍 Verifying System Health..."
    
    # Wait a bit for servers to fully start
    sleep 10
    
    # Check backend API
    if command_exists curl; then
        print_status "Checking backend API..."
        if curl -s http://localhost:8000/api/metrics >/dev/null; then
            print_status "✅ Backend API responding"
        else
            print_warning "Backend API not responding yet"
        fi
    fi
    
    # Check frontend
    print_status "Checking frontend server..."
    if curl -s http://localhost:3000 >/dev/null; then
        print_status "✅ Frontend server responding"
    else
        print_warning "Frontend server not responding yet"
    fi
}

# Function to display access information
show_access_info() {
    print_header "🌐 System Ready! Access URLs:"
    echo ""
    echo -e "  ${GREEN}🌐 Frontend Dashboard:${NC} http://localhost:3000"
    echo -e "  ${GREEN}🔌 Backend API:${NC}        http://localhost:8000"
    echo -e "  ${GREEN}📚 API Documentation:${NC}  http://localhost:8000/docs"
    echo -e "  ${GREEN}🔌 WebSocket:${NC}          ws://localhost:8000/ws"
    echo ""
    print_status "🎉 OpenSeeWe Digital Twin Platform is running!"
    echo ""
    print_status "Press Ctrl+C to stop all services"
}

# Function to cleanup on exit
cleanup() {
    print_header "🛑 Stopping Services..."
    
    # Kill backend
    if [ -f ".backend.pid" ]; then
        BACKEND_PID=$(cat .backend.pid)
        if kill -0 $BACKEND_PID 2>/dev/null; then
            kill $BACKEND_PID
            print_status "Backend stopped"
        fi
        rm -f .backend.pid
    fi
    
    # Kill frontend
    if [ -f ".frontend.pid" ]; then
        FRONTEND_PID=$(cat .frontend.pid)
        if kill -0 $FRONTEND_PID 2>/dev/null; then
            kill $FRONTEND_PID
            print_status "Frontend stopped"
        fi
        rm -f .frontend.pid
    fi
    
    print_status "✅ All services stopped"
    exit 0
}

# Trap Ctrl+C
trap cleanup SIGINT SIGTERM

# Main execution
main() {
    print_header "🚀 OpenSeeWe - Smart Grid Digital Twin Platform"
    print_header "================================================"
    
    check_requirements
    install_python_deps
    install_frontend_deps
    train_ai_models
    start_backend
    start_frontend
    verify_system
    show_access_info
    
    # Keep script running
    while true; do
        sleep 1
    done
}

# Run main function
main "$@"
