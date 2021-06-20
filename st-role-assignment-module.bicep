// parameters
param storageName string = '' 
param identityName string = ''

// reference to exisiting resources outside module
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' existing ={
  name: storageName
}

resource appIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing ={
  name: identityName
}

// Role assignment
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview'={
  name: guid( resourceId(uniqueString(deployment().name),'Microsoft.Authorization/roleDefinitions', '17d1049b-9a84-46fb-8f53-869881c3d3ab'), resourceGroup().id)
  scope: storageAccount
  properties:{
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '17d1049b-9a84-46fb-8f53-869881c3d3ab') //storage account contributor
    principalId: appIdentity.properties.principalId
  }
  dependsOn:[
    appIdentity
    storageAccount
  ]
}
