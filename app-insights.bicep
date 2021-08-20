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
