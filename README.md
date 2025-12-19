# Todo API

A RESTful Todo API built with Azure Functions (isolated worker) and ASP.NET Core, deployable to Azure with free-tier services.

## Features

- **CRUD Operations**: Create, Read, Update, Delete todo items
- **Azure Functions**: Serverless, pay-per-execution model
- **Azure SQL Database**: Serverless with free tier (100,000 vCore seconds/month)
- **Infrastructure as Code**: Bicep templates for reproducible deployments
- **CI/CD**: GitHub Actions with OIDC authentication (no secrets to rotate)
- **Local Development**: InMemory database for easy testing

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/todoitems` | Get all todo items |
| GET | `/todoitems/complete` | Get completed todo items |
| GET | `/todoitems/{id}` | Get todo item by ID |
| POST | `/todoitems` | Create new todo item |
| PUT | `/todoitems/{id}` | Update todo item |
| DELETE | `/todoitems/{id}` | Delete todo item |

## Prerequisites

- [.NET 8.0 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- [Azure Functions Core Tools v4](https://docs.microsoft.com/azure/azure-functions/functions-run-local)
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) (for deployment)
- [Azure Subscription](https://azure.microsoft.com/free/) (free tier works)

## Quick Start

### Local Development

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd TodoApi
   ```

2. **Restore dependencies**
   ```bash
   dotnet restore
   ```

3. **Copy local settings**
   ```bash
   cp local.settings.example.json local.settings.json
   ```

4. **Run locally**
   ```bash
   func start
   ```
   
   Or use the helper script:
   ```bash
   ./scripts/run-local.sh
   ```

5. **Test the API**
   ```bash
   # Create a todo
   curl -X POST http://localhost:7071/todoitems \
     -H "Content-Type: application/json" \
     -d '{"name": "Learn Azure Functions", "isComplete": false}'
   
   # Get all todos
   curl http://localhost:7071/todoitems
   ```

### Run API Tests

```bash
# Start the function app in one terminal
func start

# Run tests in another terminal
./scripts/test-api.sh
```

Or use the VS Code REST Client with `tests/api-tests.http`.

## Azure Deployment

### Prerequisites

1. Azure subscription (free tier works)
2. Azure CLI installed and logged in: `az login`
3. Azure Functions Core Tools installed

### Option 1: One-Click Deploy

```bash
# Deploy everything (infrastructure + application)
./scripts/deploy.sh
```

Environment variables:
- `ENVIRONMENT`: Environment suffix (default: `dev`)
- `LOCATION`: Azure region (default: `eastus`)
- `APP_NAME`: Base name for resources (default: `todoapi`)

### Option 2: Manual Deployment

1. **Create Resource Group**
   ```bash
   az group create --name rg-todoapi-dev --location eastus
   ```

2. **Deploy Infrastructure**
   ```bash
   az deployment group create \
     --resource-group rg-todoapi-dev \
     --template-file infra/main.bicep \
     --parameters environment=dev appName=todoapi sqlAdminPassword='<your-password>'
   ```

3. **Deploy Application**
   ```bash
   dotnet publish --configuration Release --output ./publish
   cd publish
   func azure functionapp publish func-todoapi-dev --dotnet-isolated
   ```

## CI/CD with GitHub Actions

The repository includes a GitHub Actions workflow that automatically deploys to Azure when code is pushed to the `develop` branch.

### Setup OIDC Authentication

OIDC (OpenID Connect) allows GitHub Actions to authenticate to Azure without storing secrets.

1. **Run the setup script**
   ```bash
   GITHUB_ORG=your-username GITHUB_REPO=TodoApi ./scripts/setup-github-oidc.sh
   ```

2. **Add GitHub Secrets**
   
   Go to your repository's Settings → Secrets → Actions and add:
   - `AZURE_CLIENT_ID`: Application (client) ID
   - `AZURE_TENANT_ID`: Directory (tenant) ID
   - `AZURE_SUBSCRIPTION_ID`: Subscription ID
   
   The script will display these values.

3. **Push to develop branch**
   ```bash
   git checkout -b develop
   git push origin develop
   ```

### Workflow Behavior

- **Pull Request to develop**: Builds and validates (no deployment)
- **Push to develop**: Builds, deploys infrastructure, deploys application

## Project Structure

```
TodoApi/
├── .github/workflows/     # GitHub Actions CI/CD
│   └── deploy.yml
├── Data/                  # Database context
│   └── TodoDb.cs
├── Functions/             # Azure Function endpoints
│   └── TodoFunctions.cs
├── Models/                # Data models
│   ├── Todo.cs
│   └── TodoItemDTO.cs
├── infra/                 # Bicep infrastructure
│   ├── main.bicep
│   ├── main.parameters.json
│   └── modules/
│       ├── function.bicep
│       └── sql.bicep
├── scripts/               # Helper scripts
│   ├── deploy.sh          # Full deployment
│   ├── run-local.sh       # Run locally
│   ├── setup-github-oidc.sh
│   └── test-api.sh        # API tests
├── tests/                 # Test files
│   └── api-tests.http     # REST Client tests
├── Program.cs             # Application entry point
├── TodoApi.csproj         # Project file
├── host.json              # Functions host config
└── local.settings.json    # Local config (gitignored)
```

## Azure Resources

All resources use the `-dev` suffix for the development environment.

| Resource | Name Pattern | SKU/Tier | Free Tier Limits |
|----------|--------------|----------|------------------|
| Resource Group | `rg-todoapi-dev` | - | - |
| Function App | `func-todoapi-dev` | Consumption (Y1) | 1M executions/month |
| Storage Account | `sttodoapidev*` | Standard_LRS | 5GB included |
| SQL Server | `sql-todoapi-dev-*` | - | - |
| SQL Database | `sqldb-todoapi-dev` | GP_S_Gen5 (Serverless) | 100K vCore sec/month |

## Configuration

### Local Development

The `local.settings.json` file (gitignored) configures local development:

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
    "UseInMemoryDatabase": "true"
  }
}
```

### Azure Production

App Settings are configured automatically by the Bicep deployment:
- `SqlConnectionString`: Connection to Azure SQL
- `UseInMemoryDatabase`: `false`
- `APPLICATIONINSIGHTS_CONNECTION_STRING`: For monitoring

## Security

- **No secrets in code**: Connection strings are injected via App Settings
- **OIDC Authentication**: GitHub Actions uses federated credentials
- **Managed Identity**: (Future) Can be enabled for passwordless SQL access
- **HTTPS Only**: Enforced for all endpoints
- **TLS 1.2+**: Minimum TLS version for all services

## Troubleshooting

### Function App Cold Start

Azure Functions on Consumption plan may take 2-5 seconds to respond after being idle. This is normal behavior.

### Database Connection Issues

1. Verify the SQL Server firewall allows Azure services
2. Check the connection string in App Settings
3. Ensure the database is not auto-paused (check Azure portal)

### Local Development Issues

1. Ensure Azure Functions Core Tools v4 is installed: `func --version`
2. Check if port 7071 is available
3. Try running: `dotnet build && func start`

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request to `develop`

