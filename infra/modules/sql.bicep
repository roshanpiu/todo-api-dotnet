// SQL Server module - Serverless with Free tier

@description('Azure region for resources')
param location string

@description('Base name for resources')
param appName string

@description('Environment suffix')
param environment string

@description('Unique suffix for globally unique names')
param uniqueSuffix string

@description('SQL Admin username')
param adminUsername string

@description('SQL Admin password')
@secure()
param adminPassword string

@description('Function App managed identity principal ID (optional, for future use)')
param functionAppPrincipalId string = ''

// Resource naming
var sqlServerName = 'sql-${appName}-${environment}-${take(uniqueSuffix, 6)}'
var databaseName = 'sqldb-${appName}-${environment}'

// SQL Server
resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: adminUsername
    administratorLoginPassword: adminPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

// Allow Azure services to access SQL Server
resource sqlServerFirewallAzure 'Microsoft.Sql/servers/firewallRules@2023-05-01-preview' = {
  parent: sqlServer
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// SQL Database - Serverless with Free tier
// Free tier: 100,000 vCore seconds/month, 32GB storage
resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  parent: sqlServer
  name: databaseName
  location: location
  sku: {
    name: 'GP_S_Gen5'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: 1
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 34359738368 // 32 GB
    autoPauseDelay: 60 // Auto-pause after 60 minutes of inactivity
    minCapacity: json('0.5')
    useFreeLimit: true // Enable free tier
    freeLimitExhaustionBehavior: 'AutoPause' // Auto-pause when free limit is exhausted
  }
}

// Build connection string
var connectionString = 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${databaseName};Persist Security Info=False;User ID=${adminUsername};Password=${adminPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'

// Outputs
output sqlServerName string = sqlServer.name
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output databaseName string = sqlDatabase.name
output connectionString string = connectionString

