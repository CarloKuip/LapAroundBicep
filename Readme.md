# A lap around Bicep

With the recent introduction of verion 0.4, Bicep <https://github.com/Azure/bicep/releases> the language that helps you write ARM templates in an intuitive and rapid manner has reached a level of completeness that enable you to be really productive with it.

This session you are going to build a little bit of application infrastructure that will lead you through working with the basics of Bicep language and get you familiarized with the tooling in VSCode.

## Reference materials

- ARM Template reference <https://docs.microsoft.com/en-us/azure/templates/>
- Azure suggested resource naming conventions <https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming>

## Prerequisites

To be able to start this guided tour you need to:

1) Create a resource group in your private (self managed) subscription for deployment of the resources
2) Install VSCode (<https://code.visualstudio.com/Download>)
3) Install a recent Bicep (0.4 and up) <https://github.com/Azure/bicep/releases>
4) Check that when opening the file the Bicep language service get's started and the extension is recognized
5) Have Azure CLI installed on your machine <https://docs.microsoft.com/en-us/cli/azure/install-azure-cli> so we can use that to deploy

## First steps

Open Windows terminal and navigate to a directory (or cretae one) where you can strore the bicep file.
Now start VSCode in this directory by typing: "code ." and hit -enter-

Add a new file called demo.bicep
Open the new demo.bicep file you just added to the directory.

### Parameters

First we're going to add a parameter. Type "par" and wait for the intelliSense to pop up. Choose the option "parameter-default" from the list by highlighting it and hit -enter- to place the parameter. Now replace the given placholders to specify a name, type and default value for the parameter. Example:

``` Bicep
//parameters
param projectName string = 'bicep-demo'
```

In the terminal window (or on the command prompt) run the Bicep ARM template generator by:

``` Powershell
bicep build .\main-demo.bicep
```

This will generate the file "main-demo.json" which contains the generated ARM template that can be deployed.
For example using Azure CLI.

``` AzureCLI
az deployment create -g <target resource group> --template-file .\main-demo.json --verbose
```

Off course allowing you to specify parameters to override if you like.

### Variables

The same can be done for variables, so let's add one.

``` Bicep
//variables
var suffix= uniqueString(subscription().subscriptionId, subscription().tenantId)
```

In this case we assign the varibale with a string that will be uniq, based on two pieces of input) to generate a string that is unique for this resource group + subscription combo. As you can see, in Bicep we can use all of the ARM template constructs that we're already familiar with (hopefully) and there is some "syntactic sugar" added to write more brief resource declarations.

Another powerfull way to make the declaration more readble is found in string interpolation. You may have seen this in c# or other languages that support this construct. It allows for a intuitive way to format and compose a string into a more complex variant.

``` Bicep
//string interpolation
var uniqueName = '${projectName}-${suffix}'
var identityName = 'id-${uniqueName}'
var kvname = 'kv-${take(uniqueName, 9)}'
var workspaceName = 'workspace-${uniqueName}'
var insightsName = 'insights-${uniqueName}'
var hostingplanName = 'serviceplan-${uniqueName}'
var storageName  = 'st${suffix}'
```

### Resource definitions

Up next, add a keyvault resource. Type "res-k", let the Intellisense pop-up and then scroll down to "res-keyvault", hit -enter- to place the defaults. As you can see in the example below, the format of a resource is first the keyword "resource" and after that an identifier that you can use for this resource in this Bicep. Then the part of the resourcetype, including the API version is specified. After this the specification of the resource starts and it is assigned with the "=" to the resource identifier. Change the properties of the Key Vault to match below example.

``` Bicep
//resource definitions
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
```

To materialize the changes, run the build process again.
In the terminal window (or on the command prompt) run the Bicep ARM template generator by:

``` Powershell
bicep build .\main-demo.bicep
```

Inspect the generated ARM template ("main-demo.json") to see how Bicep is generating various constructs.

### Referencing other resources

We've now seen an isolated resource definition, now we'll look into combining resources and dependencies. For this we'll define a Log Analytics workspace that we'll use in an Application insights resource. In the given example you can see the reference in the Application Insights resource to the workspace id. That is resolved throughout the loganalytics workspace identifier and then using the id property of that resource. For clarity we've added the explicit dependency on the workspace but this is not always necessary, since Bicep generates thes dependencies automatically. To check this run the command "bicep build .\demo.bicep". This generates the demo.json ARM template file. To check the output, open the file in VSCode.

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
resource appServicePlan 'Microsoft.Web/serverfarms@2020-12-01'={
  name: hostingplanName
  location: rglocation
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


resource functionAppStorage 'Microsoft.Storage/storageAccounts@2021-02-01'={
  name: storageName
  location: rglocation
  kind:'StorageV2'
  sku:{
    name:'Standard_ZRS'
    tier:'Standard'
  }
}

```

### Using loops

The use of loops for creating resources provides a powerfull way to, in this case, generate multiple blob storage containers.

``` Bicep
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
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
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

```

There are a couple of things to note about this.

- First the UserAssigned managed identity is part of a collection of identities, so the newly defined identity has to be assigned to a list. However, that requires a key and value, thus an empty value is supplied, showing a quirk of ARM templates
- The application insight setup is specified with two AppSettings. We're using the "properties" key-value collection to pick the instrumentation key and connectionstring to assign as AppSettings. This shows that the resource identifier here acts as the resource() function in ARM templates, pointing us to an instance of the resource() rather than to the Id.
- In the assignement of the WebJobsStorage Appsetting we see we can utilize the ARM template function ListKeys() to return the indexed key value from the array of returned results.

### Creating a module

The next concept to use is using a module. A module is a separate file that can be used as a re-usable template. It by concept cretes a nested deployment that may also be used with a different scope (subsription, tenant, managent group). The deployment for the first set of resources is aimed at the resource group level. To accomplish this we'll make a module by adding a file called "RoleAssignmentModule.bicep".
The contents should look like the below example:

``` Bicep
// parameters
param keyVaultName string = '' 
param identityName string = ''

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
```

Notice a couple of things here:

- The "existing" keyword is used to create a reference to an instance of an already deployed/defined resource
- The scope for this module is further reduced to just the Key Vault so the assinment of the role is specific to this KeyVault instance only!

### Using a module

To use the module in the main-demo.bicep file, use this resource definition:

``` Bicep
module kvroleassignment 'RoleAssignmentModule.bicep' = {
  name: 'managedIdentityKeyVaultRole'
  scope: resourceGroup()
  params:{
    identityName: managedIdentity.name
    keyVaultName: keyVault.name
  }
}
```

What is good to note about working with modules is that there is typechecking available in VSCode. If for example a parameter is added in a module, you save the file, immediately you'll get an indicator showing yu are missing a parameter in the bicep file where you are referencing that module.

### Adding role assignment for storage account

What's left in this lap around Bicep is the role assignment required for the Managed Identity to contribute to Blob storage.
For this again we'll make a module that captures the role asisgnment.
Create a new file named: "st-role-assignment-module.bicep" and create the role assignement resource specification like this:

``` Bicep
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
```

And then reference this module in "main-demo.bicep" by specifying a new resource module, like this example:

``` Bicep
module stroleassignment 'st-role-assignment-module.bicep' ={
  name: 'managedIdentityStorageRole'
  scope: resourceGroup()
  params: {
    storageName: functionAppStorage.name
    identityName: managedIdentity.name
  }
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
