# rabobank-synapse-project
# Azure Synapse Deployment README

## Important Notes Before Execution

### 1. Pre-requisites

- **Role Assignment for Synapse Workspace Access**  
  Assigning the Synapse Workspace the **Storage Blob Data Contributor** role on the Data Lake Storage account requires a role assignment operation.  
  > ⚠️ *This involves the `Microsoft.Authorization/roleAssignments` resource provider. Therefore, the identity executing this operation must have either the **Owner** or **User Access Administrator** role at the appropriate scope (e.g., subscription or resource group).*

---

### 2. Azure Deployment Execution

This document confirms the deployment of an Azure environment using the following PowerShell command:

```powershell
New-AzDeployment -TemplateFile "path of the project main file" -Location "location"
e.g
New-AzDeployment -TemplateFile "C:\Code\synapse\main.bicep" -Location "westeurope"
```

#### Deployment Details:

- The deployment uses **`main.bicep`** as the entry point.
- This file **references** `synapse.bicep` and **orchestrates the overall deployment process**.
- **All parameter values are defined in `main.bicep`**.
  - ⚠️ *Any required changes to parameters must be made **only** within `main.bicep` to maintain configuration integrity.*

---

### 3. Post-Deployment Actions

- **Synapse Workspace Access**  
  To allow a user to access and read data in the deployed Synapse workspace, they **must be assigned the `Synapse User` role at the workspace level**. 
  <!--
    This section provides a reference link to the official Microsoft documentation on managing Synapse RBAC (Role-Based Access Control) role assignments in Azure Synapse Analytics. 
    For detailed guidance on configuring and managing role assignments, visit:
    https://learn.microsoft.com/en-us/azure/synapse-analytics/security/how-to-manage-synapse-rbac-role-assignments
  -->
