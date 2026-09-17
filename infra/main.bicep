@description('Préfixe utilisé pour nommer les ressources du POC.')
param namePrefix string = 'jalex'

@description('Région Azure de déploiement.')
param location string = resourceGroup().location

@description('Tier du plan App Service (niveau économique pour un POC).')
param appServicePlanSku string = 'B1'

var appServicePlanName = '${namePrefix}-plan'
var apiAppName = 'app-${namePrefix}-api'
var blazorAppName = 'app-${namePrefix}-blazor'
var appInsightsName = '${namePrefix}-appinsights'
var logAnalyticsName = '${namePrefix}-logs'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: appServicePlanSku
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource apiApp 'Microsoft.Web/sites@2023-12-01' = {
  name: apiAppName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|10.0'
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'AllowedOrigins__0'
          value: 'https://${blazorAppName}.azurewebsites.net'
        }
      ]
    }
    httpsOnly: true
  }
}

resource blazorApp 'Microsoft.Web/sites@2023-12-01' = {
  name: blazorAppName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|10.0'
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'ApiBaseUrl'
          value: 'https://${apiAppName}.azurewebsites.net'
        }
      ]
    }
    httpsOnly: true
  }
}

output apiUrl string = 'https://${apiApp.properties.defaultHostName}'
output blazorUrl string = 'https://${blazorApp.properties.defaultHostName}'
