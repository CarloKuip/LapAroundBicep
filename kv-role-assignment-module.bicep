// parameters
param keyVaultName string
param identityName string

// reference to existing resources outside module
resource keyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing ={
  name: keyVaultName
}

resource appIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing ={
  name: identityName
}

// Role assignment: key vault secret user, see https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#key-vault-secrets-user
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview'={
  name: guid( keyVault.id, appIdentity.id, '4633458b-17de-408a-b874-0445c86b69e6')
  scope: keyVault
  properties:{
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') 
    principalId: appIdentity.properties.principalId
  }
}
