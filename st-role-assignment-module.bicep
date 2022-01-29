// parameters
param storageName string
param identityName string

// reference to exisiting resources outside module
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' existing ={
  name: storageName
}

resource appIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing ={
  name: identityName
}

// Role assignment Storage account Contributor https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage-account-contributor
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview'={
  name: guid( storageAccount.id, appIdentity.id, '17d1049b-9a84-46fb-8f53-869881c3d3ab')
  scope: storageAccount
  properties:{
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '17d1049b-9a84-46fb-8f53-869881c3d3ab')
    principalId: appIdentity.properties.principalId
  }
}
