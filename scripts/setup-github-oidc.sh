#!/bin/bash

# Setup GitHub OIDC Authentication for Azure
# This script creates an Azure AD App Registration with federated credentials
# for GitHub Actions to authenticate without secrets

set -e

# Configuration
APP_NAME="${APP_NAME:-todoapi}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
GITHUB_ORG="${GITHUB_ORG:-}"
GITHUB_REPO="${GITHUB_REPO:-}"

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

# Validate inputs
validate_inputs() {
    if [ -z "$GITHUB_ORG" ]; then
        read -p "Enter your GitHub organization/username: " GITHUB_ORG
    fi
    
    if [ -z "$GITHUB_REPO" ]; then
        read -p "Enter your GitHub repository name: " GITHUB_REPO
    fi
    
    print_info "GitHub Repository: $GITHUB_ORG/$GITHUB_REPO"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed"
        exit 1
    fi
    print_success "Azure CLI is installed"
    
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure"
        az login
    fi
    print_success "Logged in to Azure"
}

# Create App Registration
create_app_registration() {
    print_header "Creating App Registration"
    
    local app_name="sp-${APP_NAME}-${ENVIRONMENT}-github"
    
    # Check if app already exists
    EXISTING_APP=$(az ad app list --display-name "$app_name" --query "[0].appId" -o tsv 2>/dev/null || echo "")
    
    if [ -n "$EXISTING_APP" ]; then
        print_info "App registration already exists: $app_name"
        CLIENT_ID="$EXISTING_APP"
    else
        print_info "Creating app registration: $app_name"
        CLIENT_ID=$(az ad app create --display-name "$app_name" --query appId -o tsv)
        print_success "App registration created"
    fi
    
    echo "Client ID: $CLIENT_ID"
}

# Create Service Principal
create_service_principal() {
    print_header "Creating Service Principal"
    
    # Check if service principal exists
    EXISTING_SP=$(az ad sp show --id "$CLIENT_ID" --query id -o tsv 2>/dev/null || echo "")
    
    if [ -n "$EXISTING_SP" ]; then
        print_info "Service principal already exists"
        SP_OBJECT_ID="$EXISTING_SP"
    else
        print_info "Creating service principal..."
        SP_OBJECT_ID=$(az ad sp create --id "$CLIENT_ID" --query id -o tsv)
        print_success "Service principal created"
    fi
}

# Assign role to service principal
assign_role() {
    print_header "Assigning Role"
    
    local resource_group="rg-${APP_NAME}-${ENVIRONMENT}"
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    
    # Check if resource group exists
    if az group show --name "$resource_group" &> /dev/null; then
        print_info "Assigning Contributor role to resource group: $resource_group"
        az role assignment create \
            --assignee "$CLIENT_ID" \
            --role "Contributor" \
            --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$resource_group" \
            --output none 2>/dev/null || true
        print_success "Role assigned to resource group"
    else
        print_info "Resource group doesn't exist yet. Assigning Contributor role at subscription level."
        az role assignment create \
            --assignee "$CLIENT_ID" \
            --role "Contributor" \
            --scope "/subscriptions/$SUBSCRIPTION_ID" \
            --output none 2>/dev/null || true
        print_success "Role assigned at subscription level"
    fi
}

# Create federated credential for GitHub Actions
create_federated_credential() {
    print_header "Creating Federated Credentials"
    
    TENANT_ID=$(az account show --query tenantId -o tsv)
    
    # Federated credential for develop branch
    local cred_name="github-develop"
    local subject="repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/develop"
    
    print_info "Creating federated credential for develop branch..."
    
    # Check if credential exists
    EXISTING_CRED=$(az ad app federated-credential list --id "$CLIENT_ID" --query "[?name=='$cred_name'].name" -o tsv 2>/dev/null || echo "")
    
    if [ -n "$EXISTING_CRED" ]; then
        print_info "Federated credential already exists: $cred_name"
    else
        az ad app federated-credential create \
            --id "$CLIENT_ID" \
            --parameters "{
                \"name\": \"$cred_name\",
                \"issuer\": \"https://token.actions.githubusercontent.com\",
                \"subject\": \"$subject\",
                \"description\": \"GitHub Actions for develop branch\",
                \"audiences\": [\"api://AzureADTokenExchange\"]
            }" \
            --output none
        print_success "Federated credential created for develop branch"
    fi
    
    # Federated credential for pull requests
    local pr_cred_name="github-pull-request"
    local pr_subject="repo:${GITHUB_ORG}/${GITHUB_REPO}:pull_request"
    
    print_info "Creating federated credential for pull requests..."
    
    EXISTING_PR_CRED=$(az ad app federated-credential list --id "$CLIENT_ID" --query "[?name=='$pr_cred_name'].name" -o tsv 2>/dev/null || echo "")
    
    if [ -n "$EXISTING_PR_CRED" ]; then
        print_info "Federated credential already exists: $pr_cred_name"
    else
        az ad app federated-credential create \
            --id "$CLIENT_ID" \
            --parameters "{
                \"name\": \"$pr_cred_name\",
                \"issuer\": \"https://token.actions.githubusercontent.com\",
                \"subject\": \"$pr_subject\",
                \"description\": \"GitHub Actions for pull requests\",
                \"audiences\": [\"api://AzureADTokenExchange\"]
            }" \
            --output none
        print_success "Federated credential created for pull requests"
    fi
}

# Print GitHub secrets
print_github_secrets() {
    print_header "GitHub Secrets Configuration"
    
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    TENANT_ID=$(az account show --query tenantId -o tsv)
    
    echo ""
    echo "Add the following secrets to your GitHub repository:"
    echo ""
    echo "Go to: https://github.com/$GITHUB_ORG/$GITHUB_REPO/settings/secrets/actions"
    echo ""
    echo -e "${GREEN}AZURE_CLIENT_ID${NC}"
    echo "  $CLIENT_ID"
    echo ""
    echo -e "${GREEN}AZURE_TENANT_ID${NC}"
    echo "  $TENANT_ID"
    echo ""
    echo -e "${GREEN}AZURE_SUBSCRIPTION_ID${NC}"
    echo "  $SUBSCRIPTION_ID"
    echo ""
    echo -e "${YELLOW}Note: These are not secrets per se, but identifiers.${NC}"
    echo -e "${YELLOW}OIDC authentication doesn't require storing actual secrets.${NC}"
}

# Main execution
main() {
    print_header "GitHub OIDC Setup for Azure"
    
    validate_inputs
    check_prerequisites
    create_app_registration
    create_service_principal
    assign_role
    create_federated_credential
    print_github_secrets
    
    print_header "Setup Complete!"
    echo ""
    echo "Your GitHub Actions can now authenticate to Azure using OIDC."
    echo "No secrets need to be rotated - authentication uses GitHub's identity."
}

main "$@"

