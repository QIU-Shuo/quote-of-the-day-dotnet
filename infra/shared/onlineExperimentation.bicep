metadata description = 'Creates an online experiment workspace'
param name string
param location string = resourceGroup().location
param tags object = {}
param principalId string
param logAnalyticsWorkspaceName string
param storageAccountName string
param appConfigName string

resource onlineExperimentDataOwnerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' existing = {
  name: '53747cdd-e97c-477a-948c-b587d0e514b2' // Online Experimentation Data Owner
}


// Noite: no intellisense during private preview period
#disable-next-line BCP081
resource onlineExperimentWorkspace  'Microsoft.OnlineExperimentation/workspaces@2025-05-31-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'F0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspace.id
    logsExporterStorageAccountResourceId: storageAccount.id
    appConfigurationResourceId: appConfig.id
  }
}

resource dataOwnerUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: onlineExperimentWorkspace 
  name: guid(resourceGroup().id, principalId, onlineExperimentDataOwnerRole.id)
  properties: {
    principalId: principalId
    roleDefinitionId: onlineExperimentDataOwnerRole.id
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview'  existing = {
  name: logAnalyticsWorkspaceName
}

resource storageAccount  'Microsoft.Storage/storageAccounts@2022-09-01'  existing = {
  name: storageAccountName
}

resource appConfig 'Microsoft.AppConfiguration/configurationStores@2023-09-01-preview'  existing = {
  name: appConfigName
}

output workspaceName string = onlineExperimentWorkspace.name
output workspaceEndpoint string = onlineExperimentWorkspace.properties.endpoint
output workspaceIdentityPrincipalId string = onlineExperimentWorkspace.identity.principalId
