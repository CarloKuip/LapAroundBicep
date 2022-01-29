param uniqueName string
param managedIdentityName string
param hostingPlanName string
@secure()
param appInsightsKey string
@secure()
param appInsightsConnectionString string
@secure()
param functionAppStorageConnectionString string

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing={
  name: managedIdentityName
}

resource appServicePlan 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: hostingPlanName
  location: resourceGroup().location
  kind: 'linux'
  properties: {
    targetWorkerCount: 1
    reserved: true
  }
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
}

resource PSfunctionApp 'Microsoft.Web/sites@2020-12-01' = {
  name: 'function-${uniqueName}'
  kind: 'functionapp,linux'
  location: resourceGroup().location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlan.id
    enabled: true
    siteConfig: {
      alwaysOn: false
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsightsKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'powershell'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME_VERSION'
          value: '~7'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=${functionAppStorageConnectionString}'
        }
      ]
    }
    keyVaultReferenceIdentity: managedIdentity.id
  }
}
