param insightsName string
param logAnalyticsWorkspaceId string 
param tags object

resource appInsights 'Microsoft.Insights/components@2020-02-02'={
  name: insightsName
  location: resourceGroup().location
  kind: 'web'
  properties:{
    Application_Type:'web'
    WorkspaceResourceId:logAnalyticsWorkspaceId
  }
  tags: tags
}

output instrumentation_key string = appInsights.properties.InstrumentationKey
output connection_string string = appInsights.properties.ConnectionString 
