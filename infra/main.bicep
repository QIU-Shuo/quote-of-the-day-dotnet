targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@description('Id of the user or app to assign application roles')
param principalId string = ''

@secure()
param quoteOfTheDayDefinition object

param LAWname string
param location string
param LAWsku string
param AIname string
param AItype string
param AIrequestSource string
param AACname string
param AACsku string
param AACsoftDeleteRetentionInDays int
param AACenablePurgeProtection bool
param AACdisableLocalAuth bool

param onlineExperimentWorkspaceLocation string = 'eastus2' // Currently Experiment Workspace only has presense in eastus2

// Tags that should be applied to all resources.
// 
// Note that 'azd-service-name' tags should be applied separately to service host resources.
// Example usage:
//   tags: union(tags, { 'azd-service-name': <service name in azure.yaml> })
var tags = {
  'azd-env-name': environmentName
}

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

module monitoring './shared/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    location: location
    logAnalyticsName: '${LAWname}${resourceToken}'
    applicationInsightsName: '${AIname}${resourceToken}'
    AIrequestSource: AIrequestSource
    AItype: AItype    
    LAWsku: LAWsku
    tags: tags
  }
  scope: rg
}

module storageAccount './shared/storage.bicep' = {
  name: 'storage'
  scope: rg
  params: {
    location: location
    storageAccountName: '${resourceToken}storage'
    storageAccountType: 'Standard_LRS'
  }
}

module appConfiguration './shared/appConfiguration.bicep' = {
  name: 'appConfiguration'
  params: {
    AACdisableLocalAuth: AACdisableLocalAuth
    AACenablePurgeProtection: AACenablePurgeProtection
    AACsoftDeleteRetentionInDays: AACsoftDeleteRetentionInDays
    AACsku: AACsku
    location: location
    name: '${AACname}${resourceToken}'
    applicationInsightsId: monitoring.outputs.applicationInsightsId
  }
  scope: rg
}

module appConfigDataOwnerAccess './shared/role.bicep' = {
  scope: rg
  name: 'app-config-data-owner-role'
  params: {
    principalId: principalId
    roleDefinitionId: '5ae67dd6-50cb-40e7-96ff-dc2bfa4b606b' // App Configuration Data Owner
  }
}

module onlineExperimentWorkspace './shared/onlineExperimentation.bicep' = {
  name: 'online-experiment-workspace'
  scope: rg
  params: {
    name: 'online-exp-${substring(resourceToken, 0, 10)}'
    location: onlineExperimentWorkspaceLocation
    tags: tags
    principalId: principalId
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
    storageAccountName: storageAccount.outputs.storageAccountName
    appConfigName: appConfiguration.outputs.appConfigurationName
  }
}

// Allow online experiment workspace read access to storage
module logAnalyticsExpAccess './shared/role.bicep' = {
  scope: rg
  name: 'storage-account-exp-role'
  params: {
    principalId: onlineExperimentWorkspace.outputs.workspaceIdentityPrincipalId
    roleDefinitionId: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1' // Storage Blob Data Reader
  }
}

// Allow online experiment workspace read access to log analytics workspace
module storageAccountExpAccess './shared/role.bicep'  = {
  scope: rg
  name: 'log-analytics-exp-role'
  params: {
    principalId: onlineExperimentWorkspace.outputs.workspaceIdentityPrincipalId
    roleDefinitionId: '73c42c96-874c-492b-b04d-ab87d138a893' // Log Analytics Reader
  }
}

// Provision summary rules aggregating data for experiment workspace
var ruleDefinitions = loadYamlContent('./la-summary-rules.yaml')
module summaryRules './shared/summaryRules.bicep' =  [ for (rule, i) in ruleDefinitions.summaryRules:  {
  name: 'loganalytics-summaryrule-${i}'
  scope: rg
  params: {
    location: location
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
    summaryRuleName: rule.name
    description: rule.description
    query: rule.query
    binSize: rule.binSize // see choices at https://aka.ms/LogsSummaryRule#create-or-update-a-summary-rule
    destinationTable: rule.destinationTable
  }
} ]

module dataExportRule './shared/dataExport.bicep' = {
  name: 'loganalytics-dataexportrule'
  scope: rg
  params: {
    name: 'exp-dataexportrule'
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
    storageAccountName: storageAccount.outputs.storageAccountName
    tables: [
      'AppEvents'
      //'AppEvents_CL' -- add this later once we have summary rules that writes to this table
    ]
  }
  dependsOn: [
    summaryRules
  ]
}

module appServicePlan './shared/appserviceplan.bicep' = {
  name: 'apps-env'
  params: {
    name: '${abbrs.appManagedEnvironments}${resourceToken}'
    location: location
    tags: tags
  }
  scope: rg
}

module quoteOfTheDay './app/QuoteOfTheDay.bicep' = {
  name: 'QuoteOfTheDay'
  params: {
    name: '${abbrs.appContainerApps}quoteoftheda-${resourceToken}'
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    appDefinition: quoteOfTheDayDefinition
    appServicePlanId: appServicePlan.outputs.id
    appConfigurationName: appConfiguration.outputs.appConfigurationName
  }
  scope: rg
}

output APPCONFIG_ENDPOINT string = appConfiguration.outputs.appConfigurationEndpoint
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
output ONLINE_EXPERIMENT_WORKSPACE_ENDPOINT string = onlineExperimentWorkspace.outputs.workspaceEndpoint
