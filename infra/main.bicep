// Main Bicep template for Todo API infrastructure
// Deploys: Function App (Consumption), Storage Account, SQL Server + Database

@description('Environment name suffix (e.g., dev, prod)')
param environment string = 'dev'

@description('Azure region for resources')
param location string = resourceGroup().location

@description('Base name for resources')
param appName string = 'todoapi'

@description('SQL Server admin username')
param sqlAdminUsername string = 'sqladmin'

@description('SQL Server admin password')
@secure()
param sqlAdminPassword string

// Generate unique suffix for globally unique names
var uniqueSuffix = uniqueString(resourceGroup().id)

// Deploy Storage Account and Function App
module functionApp 'modules/function.bicep' = {
  name: 'functionApp-deployment'
  params: {
    location: location
    appName: appName
    environment: environment
    uniqueSuffix: uniqueSuffix
    sqlConnectionString: sqlServer.outputs.connectionString
  }
}

// Deploy SQL Server and Database
module sqlServer 'modules/sql.bicep' = {
  name: 'sqlServer-deployment'
  params: {
    location: location
    appName: appName
    environment: environment
    uniqueSuffix: uniqueSuffix
    adminUsername: sqlAdminUsername
    adminPassword: sqlAdminPassword
  }
}

// Outputs
output functionAppName string = functionApp.outputs.functionAppName
output functionAppUrl string = functionApp.outputs.functionAppUrl
output sqlServerName string = sqlServer.outputs.sqlServerName
output sqlDatabaseName string = sqlServer.outputs.databaseName
output resourceGroupName string = resourceGroup().name

