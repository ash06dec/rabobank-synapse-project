/*
  This Bicep file provisions the foundational infrastructure for an Azure Synapse Analytics proof-of-concept environment for the Rabobank assignment. It defines parameters for naming conventions, locations, and resource tags, and sets the deployment scope at the subscription level.

  Key components:
  - Creates a resource group for the Synapse environment.
  - Deploys a Synapse workspace using a referenced module, passing in configuration parameters such as workspace name, default container, SQL admin username, managed resource group, Data Lake account, Log Analytics settings, and tags.
  - All resources are tagged for environment and project identification.

  Parameters:
  - baseName: Base string used for naming all resources.
  - resourceGroupName: Name of the resource group to be created.
  - synapseDefaultContainerName: Default container name for Synapse.
  - synapseWorkspaceName: Name of the Synapse workspace.
  - resourceLocation: Location for resource deployment.
  - synapseSqlAdminUserName: Admin username for Synapse SQL.
  - synapseManagedRGName: Name for the Synapse managed resource group.
  - workspaceDataLakeAccountName: Name for the Data Lake Storage account.
  - logAnalyticsDestinationType: Destination type for Log Analytics.
  - logAnalyticsWorkspaceName: Name for the Log Analytics workspace.
  - tags: Object containing resource tags.
  - resourceGroupLocation: Location for the resource group.

  Modules:
  - synapse: Deploys the Synapse workspace and related resources using the specified parameters.
*/
param baseName string = 'mysynapsepoc'
param resourceGroupName string = '${baseName}-rg'
param synapseDefaultContainerName string = '${baseName}container'
param synapseWorkspaceName string = '${baseName}01'
param resourceLocation string = resourceGroupLocation
param synapseSqlAdminUserName string = '${baseName}sqladmin'
param synapseManagedRGName string = '${baseName}-managed-rg'
param workspaceDataLakeAccountName string = '${baseName}datalake'
param logAnalyticsDestinationType string = 'AzureDiagnostics'
param logAnalyticsWorkspaceName string = '${baseName}LogsWorkspace'
param tags object = {
  environment: 'rabo'
  project: 'synapse-poc'
}
param resourceGroupLocation string = 'west europe'
targetScope='subscription'

@description('The name of the resource group to create.')
resource newRG 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: resourceGroupName
  location: resourceGroupLocation
  tags: tags
}

@description('Synapse Workspace Deployment')
module synapse 'synapseIaC/synapse.bicep' = {
  name: 'synapseWorkSpaceDeployment'
  scope: newRG
  params: {
    tags: tags
    baseName: baseName
    synapseWorkspaceName: synapseWorkspaceName
    synapseDefaultContainerName: synapseDefaultContainerName
    synapseSqlAdminUserName: synapseSqlAdminUserName
    resourceLocation: resourceLocation
    synapseManagedRGName: synapseManagedRGName
    workspaceDataLakeAccountName: workspaceDataLakeAccountName
    logAnalyticsDestinationType: logAnalyticsDestinationType
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName

    }
}
