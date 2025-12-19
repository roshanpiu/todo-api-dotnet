#!/bin/bash

# Deploy Todo API to Azure
# This script deploys infrastructure (Bicep) and the Function App

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Configuration
ENVIRONMENT="${ENVIRONMENT:-dev}"
LOCATION="${LOCATION:-eastus}"
APP_NAME="${APP_NAME:-todoapi}"
RESOURCE_GROUP="rg-${APP_NAME}-${ENVIRONMENT}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}$1${NC}"
    echo -e "${YELLOW}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}→ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it first."
        echo "Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi
    print_success "Azure CLI is installed"
    
    # Check .NET SDK
    if ! command -v dotnet &> /dev/null; then
        print_error ".NET SDK is not installed. Please install it first."
        exit 1
    fi
    print_success ".NET SDK is installed"
    
    # Check Azure Functions Core Tools
    if ! command -v func &> /dev/null; then
        print_error "Azure Functions Core Tools is not installed."
        echo "Install with: npm install -g azure-functions-core-tools@4"
        exit 1
    fi
    print_success "Azure Functions Core Tools is installed"
    
    # Check if logged in to Azure
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure. Running 'az login'..."
        az login
    fi
    print_success "Logged in to Azure"
    
    # Show current subscription
    SUBSCRIPTION=$(az account show --query name -o tsv)
    print_info "Current subscription: $SUBSCRIPTION"
}

# Generate SQL password
generate_password() {
    # Generate a strong password (20 chars, mixed case, numbers, special chars)
    openssl rand -base64 24 | tr -d '/+=' | head -c 20
    echo '!Aa1'  # Append to ensure complexity requirements
}

# Deploy infrastructure
deploy_infrastructure() {
    print_header "Deploying Infrastructure"
    
    # Create resource group if it doesn't exist
    print_info "Creating resource group: $RESOURCE_GROUP"
    az group create \
        --name "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --output none
    print_success "Resource group ready"
    
    # Generate SQL admin password
    SQL_PASSWORD=$(generate_password)
    print_info "Generated SQL admin password (stored temporarily)"
    
    # Deploy Bicep template
    print_info "Deploying Bicep template..."
    DEPLOYMENT_OUTPUT=$(az deployment group create \
        --resource-group "$RESOURCE_GROUP" \
        --template-file "$PROJECT_DIR/infra/main.bicep" \
        --parameters environment="$ENVIRONMENT" \
        --parameters appName="$APP_NAME" \
        --parameters sqlAdminPassword="$SQL_PASSWORD" \
        --query "properties.outputs" \
        --output json)
    
    # Extract outputs
    FUNCTION_APP_NAME=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.functionAppName.value')
    FUNCTION_APP_URL=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.functionAppUrl.value')
    SQL_SERVER_NAME=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.sqlServerName.value')
    
    print_success "Infrastructure deployed"
    echo ""
    echo "Deployed resources:"
    echo "  Function App: $FUNCTION_APP_NAME"
    echo "  Function URL: $FUNCTION_APP_URL"
    echo "  SQL Server: $SQL_SERVER_NAME"
}

# Build and deploy application
deploy_application() {
    print_header "Deploying Application"
    
    cd "$PROJECT_DIR"
    
    # Build the project
    print_info "Building project..."
    dotnet build --configuration Release
    print_success "Build completed"
    
    # Publish the project
    print_info "Publishing project..."
    dotnet publish --configuration Release --output ./publish
    print_success "Publish completed"
    
    # Deploy to Azure Functions
    print_info "Deploying to Azure Functions..."
    cd publish
    func azure functionapp publish "$FUNCTION_APP_NAME" --dotnet-isolated
    cd ..
    
    # Clean up publish folder
    rm -rf ./publish
    
    print_success "Application deployed"
}

# Apply database migrations
apply_migrations() {
    print_header "Database Setup"
    
    print_info "Note: EF Core migrations should be applied separately if needed."
    print_info "For initial setup, the database schema will be created on first request."
    print_info "To add migrations, run: dotnet ef migrations add <MigrationName>"
}

# Print summary
print_summary() {
    print_header "Deployment Complete!"
    
    echo ""
    echo "Resources deployed to: $RESOURCE_GROUP"
    echo ""
    echo "Function App URL: $FUNCTION_APP_URL"
    echo ""
    echo "API Endpoints:"
    echo "  GET    $FUNCTION_APP_URL/todoitems"
    echo "  GET    $FUNCTION_APP_URL/todoitems/complete"
    echo "  GET    $FUNCTION_APP_URL/todoitems/{id}"
    echo "  POST   $FUNCTION_APP_URL/todoitems"
    echo "  PUT    $FUNCTION_APP_URL/todoitems/{id}"
    echo "  DELETE $FUNCTION_APP_URL/todoitems/{id}"
    echo ""
    echo -e "${YELLOW}Note: It may take a few minutes for the function app to warm up.${NC}"
}

# Main execution
main() {
    print_header "Todo API Azure Deployment"
    echo "Environment: $ENVIRONMENT"
    echo "Location: $LOCATION"
    echo "App Name: $APP_NAME"
    
    check_prerequisites
    deploy_infrastructure
    deploy_application
    apply_migrations
    print_summary
}

# Handle command line arguments
case "${1:-}" in
    --infra-only)
        check_prerequisites
        deploy_infrastructure
        ;;
    --app-only)
        if [ -z "${FUNCTION_APP_NAME:-}" ]; then
            print_error "FUNCTION_APP_NAME environment variable is required for --app-only"
            exit 1
        fi
        deploy_application
        ;;
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --infra-only   Deploy only infrastructure (Bicep)"
        echo "  --app-only     Deploy only application (requires FUNCTION_APP_NAME env var)"
        echo "  --help, -h     Show this help message"
        echo ""
        echo "Environment variables:"
        echo "  ENVIRONMENT    Environment suffix (default: dev)"
        echo "  LOCATION       Azure region (default: eastus)"
        echo "  APP_NAME       Base name for resources (default: todoapi)"
        ;;
    *)
        main
        ;;
esac

