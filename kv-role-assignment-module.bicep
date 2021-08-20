// parameters
param keyVaultName string
param identityName string

// reference to exisiting resources outside module
resource keyVault 'Microsoft.KeyVault/vaults@2021-04-01-preview' existing ={
  name: keyVaultName
}

resource appIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing ={
  name: identityName
}

// Role assignment
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview'={
  name: guid( resourceId(uniqueString(deployment().name),'Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6'), resourceGroup().id)
  scope: keyVault
  properties:{
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') //key vault secret user
    principalId: appIdentity.properties.principalId
  }
  dependsOn:[
    appIdentity
    keyVault
  ]
}
