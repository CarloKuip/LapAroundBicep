//parameters
param projectName string = 'bicep-demo'

//variables
var suffix= uniqueString(subscription().subscriptionId, subscription().tenantId)
//string interpolation
var uniqueName = '${projectName}-${suffix}'
var identityName = 'id-${uniqueName}'
var kvname = 'kv-${projectName}-${take(suffix, 9)}'
var workspaceName = 'workspace-${uniqueName}'
var insightsName = 'insights-${uniqueName}'
var hostingplanName = 'serviceplan-${uniqueName}'
var storageName  = 'st${suffix}'

//resource definitions
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: identityName
  location: resourceGroup().location
}

resource keyVault 'Microsoft.KeyVault/vaults@2021-04-01-preview' = {
  name: kvname
  location: resourceGroup().location
  properties: {
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: true
    tenantId: subscription().tenantId
    sku: {
      name: 'standard'
      family: 'A'
    }
    enableRbacAuthorization: true
  }
}

resource loganalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-10-01' ={
  name: workspaceName
  location: resourceGroup().location
  properties:{
    sku:{
      name:'Free'
    }
  }
}

module appInsights 'app-insights.bicep' ={
  name: 'appInsights-demo'
  params:{
    insightsName: insightsName
    logAnalyticsWorkspaceId: loganalyticsWorkspace.id
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2020-12-01'={
  name: hostingplanName
  location: resourceGroup().location
  kind: 'linux'
  properties:{
    targetWorkerSizeId:0
    targetWorkerCount:1
    reserved:true
  }
  sku:{
    name: 'Y1'
    tier: 'Dynamic'
  }
}

resource functionAppStorage 'Microsoft.Storage/storageAccounts@2021-04-01'={
  name: storageName
  location: resourceGroup().location
  kind:'StorageV2'
  sku:{
    name:'Standard_ZRS'
    tier:'Standard'
  }
  properties:{
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
  }
}

var blobNames = [
  'incoming'
  'outgoing'
  'quarantine'
]
resource storagecontainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' = [ for blobname in blobNames: {
 name: '${storageName}/default/${blobname}'
 dependsOn:[
   functionAppStorage
 ] 
}]

resource PSfunctionApp 'Microsoft.Web/sites@2020-12-01' = {
  name: 'function-${uniqueName}'
  kind:'functionapp,linux'
  location: resourceGroup().location
  identity: {
    type:'UserAssigned'
    userAssignedIdentities:{
      '${managedIdentity.id}': {}
    }
  }
  properties:{
    serverFarmId: appServicePlan.id
    enabled: true
    siteConfig:{
      alwaysOn:false
      appSettings:[
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.outputs.instrumentation_key
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.outputs.connection_string
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
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionAppStorage.name};AccountKey=${listKeys(functionAppStorage.id, '2019-06-01').keys[0].value};EndpointSuffix=core.windows.net'
        }
      ]
    }
    keyVaultReferenceIdentity:managedIdentity.id    
  }
  dependsOn:[
    keyVault
    functionAppStorage
    appServicePlan
  ]
}

module kvroleassignment 'kv-role-assignment-module.bicep' = {
  name: 'managedIdentityKeyVaultRole'
  scope: resourceGroup()
  params:{
    identityName: managedIdentity.name
    keyVaultName: keyVault.name
  }
}

module stroleassignment 'st-role-assignment-module.bicep' ={
  name: 'managedIdentityStorageRole'
  scope: resourceGroup()
  params: {
    storageName: functionAppStorage.name
    identityName: managedIdentity.name
  }
}
