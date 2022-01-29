# A lap around Bicep

With the release (<https://github.com/Azure/bicep/releases>) of version 0.4 in June 2021 Bicep, the language that helps you write ARM templates in an intuitive and rapid manner, has reached a level of completeness that enables you to be highly productive with it. All later versions are improving and building new capabilities so developers can become even more productive and are able to address more Azure resource types. 

This "lap around Bicep" is intended to get you familiarized with some of the basic concepts.

## Why Bicep

TL;DR; It's just pleasant to work with ;-)

Bicep is a domain specific language specifically built to reduce cognitive load that is otherwise caused by the verbosity of the JSON format when using ARM templates. By addressing the creation of resource definitions and providing better support in the editor, a better experience is teh result. That helps shifting left a lot of the validation that otherwise on deployment would occur, reducing the time to create the right resource definitions. 

## Best practices
The Bicep team has since the creation of this walkthrough defined a lot of best practices and scenarios. 
This Lap around Bicep doesn't always follow the practice immediately because it's aim is to familiarize you with the language concepts. The best practices are found here: (<https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/scenarios-rbac>)

Roughly the process to follow when writing resource files is to first create a valid resource definition set, define which pieces are belonging together (or changing together) and the refactor them into appropriate modules. 
I personally try not to aim for a dry approach, but like coherent definitions with regards to the service I'm building.

# This session

This session you are going to build a little bit of application infrastructure that will lead you through working with the basic concepts of the Bicep language and get you familiarized with the tooling support in VSCode. Most of this makes sense if you have a bit of experience or familiarity with ARM templates.

## Reference materials

- ARM Template reference <https://docs.microsoft.com/en-us/azure/templates/>
- Azure suggested resource naming conventions <https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming>

## Prerequisites

To be able to complete this guided tour you need to:

1) Create a resource group in your private (self managed) subscription for deployment of the resources
2) Install VSCode (<https://code.visualstudio.com/Download>)
3) Install a recent Bicep (0.4 and up) <https://github.com/Azure/bicep/releases>
   1) Bicep install on your platform (<https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/install>)
4) Check that when opening the file the Bicep language service get's started and the extension is recognized
5) Have Azure CLI installed on your machine <https://docs.microsoft.com/en-us/cli/azure/install-azure-cli> so we can use that to deploy

## First steps

Open a terminal and navigate to a directory (or create one) where you can store the bicep file.
Now start VSCode in this directory (On Windows by typing: "code ." and hit -enter-)

Add a new file called main-demo.bicep
Open the new main-demo.bicep file you just added to the directory.

### Parameters

First we're going to add a parameter. Type "par" and wait for the intelliSense to pop up. Choose the option "parameter-default" from the list by highlighting it and hit -enter- to place the parameter. Now replace the given placeholders to specify a name, type and default value for the parameter. If no default is provided, the parameter becomes mandatory. 
Example:

``` Bicep

//parameters

//parameter string with defaults
param projectName string = 'bicep-demo'

```

In the terminal window (or on the command prompt) run the Bicep ARM template generator by:

``` Powershell

bicep build .\main-demo.bicep

```

This will generate the file "main-demo.json" which contains the generated ARM template that can be deployed.
For example using Azure CLI. This step is not necessary but provides feedback and, especially if you're already familiar with using ARM templates, provides insight in "how" the resulting template is built.

``` AzureCLI
az deployment create -g <target resource group> --template-file .\main-demo.json --verbose
```

Off course allowing you to specify parameters to override if you like.

### Variables

The same can be done for variables, so let's add one.

``` Bicep

// derived from context using ARM functions
var suffix = uniqueString(subscription().subscriptionId, subscription().tenantId)

```

In this case we assign the variable with a string that will be uniq, based on two pieces of input) to generate a string that is unique for this resource group + subscription combo. As you can see, in Bicep we can use all of the ARM template constructs that we're already familiar with (hopefully) and there is some "syntactic sugar" added to write more brief resource declarations.

Another powerful way to make the declaration more readable is found in string interpolation. You may have seen this in c# or other languages that support this construct. It allows for a intuitive way to format and compose a string into a more complex variant.

Speaking of complex variants, another type of variable that can be declared is the object type. This is particularly handy for defining a set of tags, as seen below.

``` Bicep

//variables 

// derived from context using ARM functions
var suffix= uniqueString(subscription().subscriptionId, subscription().tenantId)

//string interpolation
var uniqueName = '${projectName}-${suffix}'
var identityName = 'id-${uniqueName}'
var kvName = 'kv-${projectName}-${take(suffix, 9)}'
var workspaceName = 'workspace-${uniqueName}'
var insightsName = 'insights-${uniqueName}'
var hostingplanName = 'serviceplan-${uniqueName}'
var storageName  = 'st${suffix}'

// complex object type
var tags ={
  'tag 1': 'tag 1 value'
  'tag 2': 'tag 2 value'
 }


```



### Resource definitions

Up next, add a key vault resource. Type "res-k", let the Intellisense pop-up and then scroll down to "res-keyvault", hit -enter- to place the defaults. As you can see in the example below, the format of a resource is first the keyword "resource" and after that an identifier that you can use for this resource in this Bicep. Then the part of the resource type, including the API version is specified. After this the specification of the resource starts and it is assigned with the "=" to the resource identifier. Change the properties of the Key Vault to match below example.

``` Bicep
//resource definitions

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

```

### Bicep build
To materialize the changes, run the build process again.
In the terminal window (or on the command prompt) run the Bicep ARM template generator by:

``` Powershell
bicep build .\main-demo.bicep
```

Inspect the generated ARM template ("main-demo.json") to see how Bicep is generating various constructs.

### Referencing other resources

We've now seen an isolated resource definition, now we'll look into combining resources and dependencies. For this we'll define a Log Analytics workspace that we'll use in an Application insights resource. In the given example you can see the reference in the Application Insights resource to the workspace id. That is resolved throughout the log analytics workspace identifier and then using the id property of that resource. For clarity we've added the explicit dependency on the workspace but this is not always necessary, since Bicep generates these dependencies automatically. To check this run the command "bicep build .\demo.bicep". This generates the demo.json ARM template file. To check the output, open the file in VSCode.

``` Bicep
resource loganalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-10-01' ={
  name: workspaceName
  location: resourceGroup().location
  properties:{
    sku:{
      name:'Free'
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02-preview'={
  name: insightsName
  location: resourceGroup().location
  kind: 'web'
  properties:{
    Application_Type:'web'
    WorkspaceResourceId:loganalyticsWorkspace.id
  }
  dependsOn:[
    loganalyticsWorkspace
  ]
}

```

To get some exercise with the tooling, now add a storage account and App Service plan like below example.

``` Bicep

resource appServicePlan 'Microsoft.Web/serverfarms@2021-02-01'={
  name: hostingplanName
  location: resourceGroup().location
  kind: 'linux'
  properties:{
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
  }
  properties:{
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
  }

}

```

### Referencing parent resources
A nice way to build a resource hierarchy without having to stumble over the nesting depth is the use of the parent keyword and creating a reference to such a resource using the existing keyword. With defining the storage account for example and the need to create blob containers. For that we first need to resolve the blob service resource of the storage account.  We can do so by referring to the 'default' blob service of the storage account by using the parent keyword. 

``` Bicep

resource blobservice 'Microsoft.Storage/storageAccounts/blobServices@2021-06-01' existing={
  name: 'default'
  parent: functionAppStorage
}


```

### Using loops

The use of loops for creating resources provides a powerful way to, in this case, generate multiple blob storage containers.

``` Bicep

var blobNames = [
  'incoming'
  'outgoing'
  'quarantine'
]
resource storagecontainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-06-01' = [ for blobname in blobNames: {
 name: '${blobname}'
 parent: blobservice
}]

```

This loop relies on enumeration of the number of items in the provided Array, but this also works with numbers.

### Using Resource Instance References

These are the foundations, so now you can create a Function App that relies on these previously defined resources. The function app will run on linux, as defined in the APP Service Plan and the hosting environment is setup to run PowerShell (core). The resource specification should look like this:

``` Bicep

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
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionAppStorage.name};EndpointSuffix=core.windows.net'
        }
      ]
    }
    keyVaultReferenceIdentity:managedIdentity.id    
  }
  dependsOn:[
    keyVault
  ]
}

```

There are a couple of things to note about this.

- First the UserAssigned managed identity is part of a collection of identities, so the newly defined identity has to be assigned to a list. However, that requires a key and value, thus an empty value is supplied, showing a quirk of ARM templates
- The application insight setup is specified with two AppSettings. We're using the "properties" key-value collection to pick the instrumentation key and connectionstring to assign as AppSettings. This shows that the resource identifier here acts as the resource() function in ARM templates, pointing us to an instance of the resource() rather than to the Id.
- Tha application insights InstrumentationKey is not per-se necessary here since AppInsights now supports using managed Identity. Also, when using other types of secrets, best to use Key Vault getSecret('secret name') function. 

### Creating a module

The next concept to use is using a module. A module is a separate file that can be used as a re-usable template. It by concept creates a nested deployment that may also be used with a different scope (subscription, tenant, management group). The deployment for the first set of resources is aimed at the resource group level. To accomplish this we'll make a module by adding a file called "RoleAssignmentModule.bicep".
The contents should look like the below example:

``` Bicep
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

```

Notice a couple of things here:

- The "existing" keyword is used to create a reference to an instance of an already deployed/defined resource
- The scope for this module is further reduced to just the Key Vault so the assignment of the role is specific to this KeyVault instance only!

### Using a module

To use the module in the main-demo.bicep file, use this resource definition:

``` Bicep

module kvRoleAssignment 'kv-role-assignment-module.bicep' = {
  name: 'managedIdentityKeyVaultRole'
  params: {
    identityName: managedIdentity.name
    keyVaultName: keyVault.name
  }
}

```

What is good to note about working with modules is that there is typechecking available in VSCode. If for example a parameter is added in a module, you save the file, immediately you'll get an indicator showing yu are missing a parameter in the bicep file where you are referencing that module.

### Adding role assignment for storage account

What's left in this lap around Bicep is the role assignment required for the Managed Identity to contribute to Blob storage.
For this again we'll make a module that captures the role assignment.
Create a new file named: "st-role-assignment-module.bicep" and create the role assignment resource specification like this:

``` Bicep
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

```

And then reference this module in "main-demo.bicep" by specifying a new resource module, like this example:

``` Bicep

module storageRoleAssignment 'st-role-assignment-module.bicep' = {
  name: 'managedIdentityStorageRole'
  params: {
    storageName: functionAppStorage.name
    identityName: managedIdentity.name
  }
}

```

## Refactoring and using Module output

After writing a lot of Bicep code you'll end up wit large files that will undoubtedly have duplication in them. To avoid these duplications we can refactor. For example the AppInsights resource is usefull to be leveraged by other Bicep projects as well. 
To refactor, we simply create a new file called "app-insights.bicep" and first copy the resource from "main.bicep" and place it in the new file. Now we need to add input and output parameters so we can wire it up in main.bicep. The app-insights.bicep should look like this:

``` Bicep
param insightsName string
param logAnalyticsWorkspaceId string 

resource appInsights 'Microsoft.Insights/components@2020-02-02-preview'={
  name: insightsName
  location: resourceGroup().location
  kind: 'web'
  properties:{
    Application_Type:'web'
    WorkspaceResourceId:logAnalyticsWorkspaceId
  }
}

output instrumentation_key string = appInsights.properties.InstrumentationKey
output connection_string string = appInsights.properties.ConnectionString 

```

As you can see we've added the output definitions for two strings so the can be leveraged in our Function App resource, defined in main.bicep. The outputs can also be of type object so they can contain more complex data structure, but for this example a few strings is fine. The module definition, that replaces the original AppInsights resource should look like this:

``` Bicep
module appInsights 'app-insights.bicep' ={
  name: 'appInsights-demo'
  params:{
    insightsName: insightsName
    logAnalyticsWorkspaceId: loganalyticsWorkspace.id
  }
}
```

When using the output of the AppInsights module we can simply refer to the resource.outputs collection and pick the property we need, in this case the instrumentation_key and connection_string.

``` Bicep

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
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionAppStorage.name};EndpointSuffix=core.windows.net'
        }
      ]
    }
    keyVaultReferenceIdentity: managedIdentity.id
  }
}

```

## Refactoring
We can now continue to break away pieces of the main bicep and create additional modules. For example the app service fits nicely in its own module.

``` Bicep

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


```

A couple of things to note:
- We have applies th @secure() decorator to the parameters that contain sensitive information. This will prevent these values to be echoed in log files.
- We have combined the resources for the ApServicePLan and the AppService into one (separately deployable) module. 
- We have left the AppSettings in a combined definition instead of using the SiteConfig AppSettings resource. This should be further applied but for brevity we'll leave it out for now.

## Using Key Vault to get secrets
In the above resource definition there are the @secure() parameters defined. These can be loaded from Key Vault. Below example shows how that is accomplished.

``` Bicep

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


```

## Reverse engineering an ARM template

This process is not entirely "bullet proof' and returns a best effort attempt at creating a Bicep file from a given ARM template.
To try this, on the command prompt, type this command and run it.

``` Powershell
bicep decompile .\main-demo.json --outfile reversed.bicep
```

In the current state, this will build a reversed.bicep file but for this template there is a problem and bicep exits with an error. The challenge for you is to fix this.

Good luck and enjoy the use of Bicep!
