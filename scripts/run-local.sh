#!/bin/bash

# Start the Azure Functions app locally
# This script builds and runs the function app with InMemory database

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Check for Azure Functions Core Tools
if ! command -v func &> /dev/null; then
    echo "ERROR: Azure Functions Core Tools (func) not found!"
    echo ""
    echo "Please install it using one of these methods:"
    echo ""
    echo "  macOS (Homebrew):"
    echo "    brew tap azure/functions"
    echo "    brew install azure-functions-core-tools@4"
    echo ""
    echo "  npm (cross-platform):"
    echo "    npm install -g azure-functions-core-tools@4"
    echo ""
    echo "  For other options, see:"
    echo "    https://learn.microsoft.com/en-us/azure/azure-functions/functions-run-local"
    echo ""
    exit 1
fi

echo "========================================="
echo "Starting Todo API (Azure Functions)"
echo "========================================="
echo ""
echo "Project: $PROJECT_DIR"
echo ""

cd "$PROJECT_DIR"

# Ensure we have the latest build
echo "Building project..."
dotnet build

echo ""
echo "Starting Azure Functions host..."
echo "API will be available at: http://localhost:7071"
echo ""
echo "Endpoints:"
echo "  GET    /todoitems          - Get all todos"
echo "  GET    /todoitems/complete - Get completed todos"
echo "  GET    /todoitems/{id}     - Get todo by ID"
echo "  POST   /todoitems          - Create todo"
echo "  PUT    /todoitems/{id}     - Update todo"
echo "  DELETE /todoitems/{id}     - Delete todo"
echo ""
echo "Press Ctrl+C to stop"
echo "========================================="
echo ""

# Run the function app
func start

