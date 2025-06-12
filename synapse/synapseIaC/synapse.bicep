/*
  Bicep Module: Synapse Analytics Workspace Deployment

  This Bicep template provisions a secure Azure Synapse Analytics environment with supporting resources, including networking, storage, monitoring, and security configurations.

  Resources Deployed:
    - Virtual Network and subnet for Synapse and private endpoints.
    - User-assigned Managed Identity for Synapse workspace.
    - Azure Key Vault and RSA Key for customer-managed encryption (CMK).
    - Synapse Analytics Workspace with managed VNet, CMK encryption, and private endpoints.
    - Azure Data Lake Storage Gen2 account with network ACLs.
    - Role assignment for Synapse workspace managed identity as Storage Blob Data Contributor.
    - Log Analytics Workspace for monitoring.
    - Diagnostic settings for Synapse workspace, SQL pool, and storage account.
    - Auditing and extended auditing settings for Synapse workspace.
    - Private DNS zones for Blob Storage and Synapse SQL endpoints.
    - Blob service configuration for the storage account.
    - Private Endpoints and DNS zone groups for storage and Synapse SQL.
    - Dedicated Synapse SQL Pool (DW100c SKU).

  Outputs:
    - workspaceDataLakeAccountID: Resource ID of the Data Lake Storage account.
    - workspaceDataLakeAccountName: Name of the Data Lake Storage account.
    - synapseWorkspaceID: Resource ID of the Synapse workspace.
    - synapseWorkspaceName: Name of the Synapse workspace.
    - synapseSQLDedicatedEndpoint: Dedicated SQL endpoint for Synapse.
    - synapseSQLServerlessEndpoint: Serverless SQL endpoint for Synapse.
    - synapseWorkspaceIdentityPrincipalID: Principal ID of the Synapse workspace managed identity.
    - logAnalyticsWorkspaceId: Resource ID of the Log Analytics workspace.

  Notes:
    - The template enforces private networking and disables public network access for Synapse.
    - Customer-managed keys (CMK) are used for workspace encryption.
    - Diagnostic logs and metrics are sent to Log Analytics.
    - Private endpoints and DNS zones are configured for secure connectivity.
    - Ensure all required parameters are provided and have appropriate permissions for deployment.
*/
param baseName string
param synapseDefaultContainerName string
param synapseWorkspaceName string
param resourceLocation string
param synapseSqlAdminUserName string
param synapseManagedRGName string
param workspaceDataLakeAccountName string
param logAnalyticsDestinationType string
param logAnalyticsWorkspaceName string
param tags object
var dataLakeStorageAccountUrl = 'https://${workspaceDataLakeAccountName}.dfs.core.windows.net/'
var azureRBACStorageBlobDataContributorRoleID = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' //Storage Blob Data Contributor Role
param vaults_mysynapsekv_01_name string = '${baseName}kv01' // Key Vault name
param cMKKeyName string = '${baseName}cmkencryptionsynapse' // CMK Key name

// Define the Synapse workspace and related resources
resource synapsevnet 'Microsoft.Network/virtualNetworks@2024-07-01' = {
  name: 'mysynapsevnet'
  tags: tags
  location: resourceLocation
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.25.2.0/24'
      ]
    }
    subnets: [
      {
        name: 'pesynapsesubnet'
        properties: {
          addressPrefix: '10.25.2.0/27'
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}
// Managed Identity for Synapse Workspace
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: 'mysynapse-mi-01'
  tags: tags
  location: resourceLocation
  dependsOn: [
    synapsevnet
  ]
}
// Key Vault for CMK
resource vault 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: vaults_mysynapsekv_01_name
  tags: tags
  location: resourceLocation
  properties: {
    accessPolicies: [
      {
        objectId: managedIdentity.properties.principalId
        permissions: {
          keys: [
            'all'
          ]
        }
        tenantId: subscription().tenantId
      }
    ]
    enablePurgeProtection: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableRbacAuthorization: false
    tenantId: subscription().tenantId
    sku: {
      name: 'standard'
      family: 'A'
    }
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
  dependsOn: [
    managedIdentity
  ]
}
// Key Vault Key for CMK
resource key 'Microsoft.KeyVault/vaults/keys@2024-11-01' = {
  parent: vault
  tags: tags
  name: cMKKeyName
  properties: {
    kty: 'RSA'
    keyOps: []
    keySize: 2048
  }
}
// Synapse Workspace
resource r_synapseWorkspace 'Microsoft.Synapse/workspaces@2021-06-01' = {
  name: synapseWorkspaceName
  location: resourceLocation
  tags: tags
  identity: {
    type: 'SystemAssigned,UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    azureADOnlyAuthentication: false
    // cspWorkspaceAdminProperties: {
    //   initialWorkspaceAdminObjectId: '4fe7fc36-b425-420f-a3f4-5e14e084eb5e'
    // }
    defaultDataLakeStorage: {
      accountUrl: dataLakeStorageAccountUrl
      createManagedPrivateEndpoint: false
      filesystem: synapseDefaultContainerName
    }
    encryption: {
      cmk: {
        kekIdentity: {
          userAssignedIdentity: managedIdentity.id // Use a user-assigned managed identity for CMK
          useSystemAssignedIdentity: false
        }
        key: {
          keyVaultUrl: 'https://${vaults_mysynapsekv_01_name}.vault.azure.net/keys/${cMKKeyName}'
          name: cMKKeyName
        }
      }
    }
    privateEndpointConnections: [
      {
        properties: {
          privateEndpoint: {}
          privateLinkServiceConnectionState: {
            status: 'Approved'
          }
        }
      }
      {
        properties: {
          privateEndpoint: {}
          privateLinkServiceConnectionState: {
            status: 'Approved'
          }
        }
      }
      {
        properties: {
          privateEndpoint: {}
          privateLinkServiceConnectionState: {
            status: 'Approved'
          }
        }
      }
    ]
    publicNetworkAccess: 'disabled' // 'Enabled' or 'Disabled'
    sqlAdministratorLogin: synapseSqlAdminUserName
    managedResourceGroupName: synapseManagedRGName
    managedVirtualNetwork: 'default'
    managedVirtualNetworkSettings: { preventDataExfiltration: true }
    virtualNetworkProfile: {
      computeSubnetId: resourceId('Microsoft.Network/virtualNetworks/subnets', synapsevnet.name, 'pesynapsesubnet')
    }
    dependsOn: [
      vault
      key
    ]
  }
}
//Data Lake Storage Account
resource r_workspaceDataLakeAccount 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: workspaceDataLakeAccountName
  tags: tags
  location: resourceLocation
  properties: {
    isHnsEnabled: true
    accessTier: 'Hot'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'None'
      resourceAccessRules: [
        {
          tenantId: subscription().tenantId
          resourceId: r_synapseWorkspace.id
        }
      ]
    }
  }
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

//Synapse Workspace Role Assignment as Blob Data Contributor Role in the Data Lake Storage Account
//https://docs.microsoft.com/en-us/azure/synapse-analytics/security/how-to-grant-workspace-managed-identity-permissions
resource r_dataLakeRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(r_synapseWorkspace.name, r_workspaceDataLakeAccount.name)
  scope: r_workspaceDataLakeAccount
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRBACStorageBlobDataContributorRoleID)
    principalId: r_synapseWorkspace.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
// Log Analytics Workspace for Synapse
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' = {
  name: logAnalyticsWorkspaceName
  tags: tags
  location: resourceLocation
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}
// Diagnostic Settings for Synapse Workspace and SQL Pool
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'SynapseDiagnosticSettings'
  scope: r_synapseWorkspace
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logAnalyticsDestinationType: logAnalyticsDestinationType
    logs: [
      { category: 'SynapseRbacOperations', enabled: true }
      { category: 'GatewayApiRequests', enabled: true }
      { category: 'BuiltinSqlReqsEnded', enabled: true }
      { category: 'IntegrationPipelineRuns', enabled: true }
      { category: 'IntegrationActivityRuns', enabled: true }
      { category: 'IntegrationTriggerRuns', enabled: true }
      { category: 'SQLSecurityAuditEvents', enabled: true }
    ]
  }
}
// Diagnostic Settings for Synapse SQL Pool
resource sqlPoolDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'SqlPoolDiagnosticSettings'
  scope: synapseSqlPool
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logAnalyticsDestinationType: logAnalyticsDestinationType
    logs: [
      {
        categoryGroup: 'audit'
        enabled: true
      }
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}
// Diagnostic Settings for Data Lake Storage Account
resource sadiagnostic 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'storageDiagnosticSettings'
  scope: r_workspaceDataLakeAccount
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logAnalyticsDestinationType: logAnalyticsDestinationType
    logs: []
    metrics: [
      {
        category: 'Transaction'
        enabled: true
        timeGrain: 'PT1M'
      }
    ]
  }
}
// Synapse Workspace Auditing Settings
resource workspaceName_auditsettings 'Microsoft.Synapse/workspaces/auditingSettings@2021-06-01' = {
  parent: r_synapseWorkspace
  name: 'auditsettings'
  properties: {
    auditActionsAndGroups: [
      'BATCH_COMPLETED_GROUP'
      'SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP'
      'FAILED_DATABASE_AUTHENTICATION_GROUP'
    ]
    retentionDays: 0
    state: 'Enabled'
    isAzureMonitorTargetEnabled: true
  }
  dependsOn: [
    synapseSqlPool
  ]
}
// Synapse Workspace Extended Auditing Settings
resource workspaceName_extendedaudit 'Microsoft.Synapse/workspaces/extendedAuditingSettings@2021-06-01' = {
  parent: r_synapseWorkspace
  name: 'extendedaudit'
  properties: {
    auditActionsAndGroups: [
      'BATCH_COMPLETED_GROUP'
      'SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP'
      'FAILED_DATABASE_AUTHENTICATION_GROUP'
    ]
    retentionDays: 0
    state: 'Enabled'
    isAzureMonitorTargetEnabled: true
  }
  dependsOn: [
    synapseSqlPool
  ]
}
// Private DNS Zone for Blob Storage
resource blobPrivDNS 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.blob.${environment().suffixes.storage}'
  location: 'global'
}
// Private DNS Zone for SQL Server
resource sqlPrivDNS 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink${environment().suffixes.sqlServerHostname}'
  location: 'global'
}
// Blob Service for Data Lake Storage Account
resource storageAccountName_default 'Microsoft.Storage/storageAccounts/blobServices@2024-01-01' = {
  parent: r_workspaceDataLakeAccount
  name: 'default'
  properties: {
    changeFeed: {
      enabled: false
    }
    restorePolicy: {
      enabled: false
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    cors: {
      corsRules: []
    }
    deleteRetentionPolicy: {
      allowPermanentDelete: false
      enabled: true
      days: 7
    }
    isVersioningEnabled: false
  }
}
// Private Endpoint for Data Lake Storage Account
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-07-01' = {
  name: 'peforstorageacc'
  tags: tags
  location: resourceLocation
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'peforstorageacc'
        properties: {
          privateLinkServiceId: resourceId('Microsoft.Storage/storageAccounts', r_workspaceDataLakeAccount.name)
          groupIds: [
            'blob'
          ]
          privateLinkServiceConnectionState: {
            status: 'Approved'
            description: 'Auto-Approved'
            actionsRequired: 'None'
          }
        }
      }
    ]
    manualPrivateLinkServiceConnections: []
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', synapsevnet.name, 'pesynapsesubnet')
    }
    customDnsConfigs: []
  }
}
// Private DNS Zone Group for Blob Storage
resource privateEndpoints_DNS_blob 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-07-01' = {
  name: 'default'
  parent: privateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: blobPrivDNS.name
        properties: {
          privateDnsZoneId: blobPrivDNS.id
        }
      }
    ]
  }
  dependsOn: []
}
// Synapse SQL Pool (Dedicated SQL Pool)
resource synapseSqlPool 'Microsoft.Synapse/workspaces/sqlPools@2021-06-01' = {
  name: '${synapseWorkspaceName}sql'
  parent: r_synapseWorkspace
  location: resourceLocation
  sku: {
    name: 'DW100c' // Choose an appropriate SKU'
    capacity: 0 // 0 for serverless, or specify a number for provisioned  
  }
  properties: {
    createMode: 'Default'
    collation: 'SQL_Latin1_General_CP1_CI_AS'
  }
  dependsOn: [
    r_synapseWorkspace
  ]
}
// Private DNS Zone for Synapse SQL Pool
resource sqlprivateEndpoint 'Microsoft.Network/privateEndpoints@2024-07-01' = {
  name: 'pesql'
  tags: tags
  location: resourceLocation
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'pesql'
        properties: {
          privateLinkServiceId: resourceId('Microsoft.Synapse/workspaces', r_synapseWorkspace.name)
          groupIds: [
            'sqlondemand' // Use 'sql' for dedicated SQL pools
          ]
          privateLinkServiceConnectionState: {
            status: 'Approved'
            description: 'Auto-Approved'
            actionsRequired: 'None'
          }
        }
      }
    ]
    manualPrivateLinkServiceConnections: []
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', synapsevnet.name, 'pesynapsesubnet')
    }
    customDnsConfigs: []
  }
}
// Private DNS Zone for Synapse SQL Pool
resource privateEndpoints_dns_sqlondemand 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-07-01' = {
  name: 'defaultsqlondemand'
  parent: sqlprivateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: sqlPrivDNS.name
        properties: {
          privateDnsZoneId: sqlPrivDNS.id
        }
      }
    ]
  }
  dependsOn: []
}
// Outputs
output workspaceDataLakeAccountID string = r_workspaceDataLakeAccount.id
output workspaceDataLakeAccountName string = r_workspaceDataLakeAccount.name
output synapseWorkspaceID string = r_synapseWorkspace.id
output synapseWorkspaceName string = r_synapseWorkspace.name
output synapseSQLDedicatedEndpoint string = r_synapseWorkspace.properties.connectivityEndpoints.sql
output synapseSQLServerlessEndpoint string = r_synapseWorkspace.properties.connectivityEndpoints.sqlOnDemand
output synapseWorkspaceIdentityPrincipalID string = r_synapseWorkspace.identity.principalId
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
