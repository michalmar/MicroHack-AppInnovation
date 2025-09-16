@description('Location for all resources (defaults to the resource group location)')
param location string = resourceGroup().location

@description('Administrator login for the SQL server')
param adminLogin string = 'sqladmin'

@secure()
@description('Administrator password for the SQL server (secure)')
param adminPassword string

@description('IPv4 address of the application to whitelist (single IP). Example: 203.0.113.5')
param appIp string

@description('Database name')
param databaseName string = 'appdb'

@description('Container CPU for the web app (string decimal, e.g. "0.5")')
param containerCpu string = '0.5'

@description('Container memory for the web app (string, e.g. 1Gi, 512Mi)')
param containerMemory string = '1Gi'

// Use unique string seeded with the full resource group id so name is globally unique
var serverName = toLower('sql-${uniqueString(resourceGroup().id)}')

resource sqlServer 'Microsoft.Sql/servers@2024-11-01-preview' = {
  name: serverName
  location: location
  properties: {
    administratorLogin: adminLogin
    administratorLoginPassword: adminPassword
    // Allow public endpoint (the firewall rule below limits access to the provided IP)
    publicNetworkAccess: 'Enabled'
    minimalTlsVersion: '1.2'
  }
  tags: {
    deployedBy: 'bicep-template'
  }
}

// Create a firewall rule to whitelist the single IP
resource allowAppIp 'Microsoft.Sql/servers/firewallRules@2024-11-01-preview' = {
  parent: sqlServer
  name: 'AllowAppIP'
  properties: {
    startIpAddress: appIp
    endIpAddress: appIp
  }
}

// Serverless single database in General Purpose tier with autoscaling and auto-pause
resource database 'Microsoft.Sql/servers/databases@2024-11-01-preview' = {
  parent: sqlServer
  name: databaseName
  location: location
  sku: {
    // GP_S_Gen5 indicates General Purpose Serverless Gen5 family; capacity sets the max vCores
    name: 'GP_S_Gen5'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: 2
  }
  properties: {
    // Auto-pause after 60 minutes (1 hour)
    autoPauseDelay: 60
  // Minimum capacity (vCores) when not paused. Use integer where ARM schema requires int (use 1 here).
  // Note: some CLI/PS examples accept fractional values like 0.5; adjust if your API version supports it.
  minCapacity: 1
    // maxSizeBytes left to default. Adjust if you need a specific size.
  }
  tags: {
    purpose: 'serverless-db'
  }
}

output sqlServerName string = sqlServer.name
output sqlFullyQualifiedDomainName string = '${sqlServer.name}.database.windows.net'
output databaseNameOut string = database.name

// --- Container registry & Container Apps resources ---
// Azure Container Registry (used to store the web app container image)
resource acr 'Microsoft.ContainerRegistry/registries@2021-09-01' = {
  name: toLower('acr${uniqueString(resourceGroup().id)}')
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: true
  }
  tags: {
    purpose: 'container-registry'
  }
}

// Log Analytics workspace required by Container Apps environment
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2020-08-01' = {
  name: toLower('law-${uniqueString(resourceGroup().id)}')
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Container Apps managed environment
resource containerAppEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: toLower('aca-env-${uniqueString(resourceGroup().id)}')
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        // use listKeys with the workspace resource id to retrieve the shared key
        sharedKey: listKeys(resourceId('Microsoft.OperationalInsights/workspaces', logAnalytics.name), '2020-08-01').primarySharedKey
      }
    }
  }
  tags: {
    purpose: 'container-apps-env'
  }
}

// Retrieve ACR admin credentials so we can register the registry with the Container App
var acrCreds = listCredentials(acr.id, '2019-05-01')

// Container App (runs the web app image stored in ACR)
resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'legocatalog-app'
  location: location
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
      }
      registries: [
        {
          server: '${acr.name}.azurecr.io'
          username: acrCreds.username
          passwordSecretRef: 'acr-password'
        }
      ]
      secrets: [
        {
          name: 'acr-password'
          value: acrCreds.passwords[0].value
        }
        {
          name: 'sql-conn'
          value: format('Server={0}.database.windows.net;Initial Catalog={1};User ID={2};Password={3};Encrypt=True;TrustServerCertificate=False;', sqlServer.name, database.name, adminLogin, adminPassword)
        }
      ]
    }
    template: {
      // containers: [
      //   {
      //     name: 'legocatalog'
      //     image: '${acr.name}.azurecr.io/lego-catalog:latest'
      //     resources: {
      //       cpu: json(containerCpu)
      //       memory: containerMemory
      //     }
      //     env: [
      //       {
      //         name: 'ConnectionStrings__DefaultConnection'
      //         secretRef: 'sql-conn'
      //       }
      //     ]
      //   }
      // ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }
  }
  tags: {
    purpose: 'legocatalog-containerapp'
  }
}

output acrLoginServer string = '${acr.name}.azurecr.io'
output acrName string = acr.name
output containerAppFqdn string = containerApp.properties.configuration.ingress.fqdn
