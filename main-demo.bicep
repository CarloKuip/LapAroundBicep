//parameters

//parameter string with defaults
param projectName string = 'bicep-demo'

//variables 

// derived from context using ARM functions
var suffix = uniqueString(subscription().subscriptionId, subscription().tenantId)
//string interpolation
var uniqueName = '${projectName}-${suffix}'
var identityName = 'id-${uniqueName}'
var kvName = 'kv-${projectName}-${take(suffix, 9)}'
var workspaceName = 'workspace-${uniqueName}'
var insightsName = 'insights-${uniqueName}'
var hostingplanName = 'serviceplan-${uniqueName}'
var storageName = 'st${suffix}'

// complex object type
var tags = {
  'tag 1': 'tag 1 value'
  'tag 2': 'tag 2 value'
}

//resource definitions
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: identityName
  location: resourceGroup().location
}

resource keyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' = {
  name: kvName
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
  tags: tags
}

resource loganalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: workspaceName
  location: resourceGroup().location
  properties: {
    sku: {
      name: 'Free'
    }
  }
}

module appInsights 'app-insights.bicep' = {
  name: 'appInsights-demo'
  params: {
    insightsName: insightsName
    logAnalyticsWorkspaceId: loganalyticsWorkspace.id
    tags: tags
  }
}

resource functionAppStorage 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: storageName
  location: resourceGroup().location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_ZRS'
  }
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
  }
}

resource blobservice 'Microsoft.Storage/storageAccounts/blobServices@2021-06-01' existing = {
  name: 'default'
  parent: functionAppStorage
}

var blobNames = [
  'incoming'
  'outgoing'
  'quarantine'
]
resource storagecontainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-06-01' = [for blobname in blobNames: {
  name: '${blobname}'
  parent: blobservice
}]


module kvRoleAssignment 'kv-role-assignment-module.bicep' = {
  name: 'managedIdentityKeyVaultRole'
  params: {
    identityName: managedIdentity.name
    keyVaultName: keyVault.name
  }
}

module storageRoleAssignment 'st-role-assignment-module.bicep' = {
  name: 'managedIdentityStorageRole'
  params: {
    storageName: functionAppStorage.name
    identityName: managedIdentity.name
  }
}

module appService 'appservice.bicep' ={
  name: 'appservice-deployment'
  params:{
    appInsightsConnectionString: appInsights.outputs.connection_string
    appInsightsKey: appInsights.outputs.instrumentation_key
    functionAppStorageConnectionString: keyVault.getSecret('webJobStorageConnectionString')
    hostingPlanName: hostingplanName
    managedIdentityName: managedIdentity.name
    uniqueName: uniqueName
  }
  dependsOn:[
    storageRoleAssignment
    kvRoleAssignment
  ]
}
