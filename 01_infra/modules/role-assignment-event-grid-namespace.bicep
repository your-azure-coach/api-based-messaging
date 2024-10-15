// Scope
targetScope = 'resourceGroup'

// Parameters
@allowed([
  'EventGrid Contributor'
  'EventGrid Data Sender'
  'EventGrid Data Receiver'
])
param roleName string
param eventGridNamespaceName string
param principalId string
@allowed([
  'Device'
  'ForeignGroup'
  'Group'
  'ServicePrincipal'
  'User'
])
param principalType string

// variables
var roleIds = {
  'EventGrid Contributor': resourceId('Microsoft.Authorization/roleAssignments', '1e241071-0855-49ea-94dc-649edcd759de')
  'EventGrid Data Sender': resourceId('Microsoft.Authorization/roleAssignments', 'd5a91429-5739-47e2-a06b-3470a27159e7')
  'EventGrid Data Receiver': resourceId('Microsoft.Authorization/roleAssignments', '78cbd9e7-9798-4e2e-9b5a-547d9ebb31fb')
  }

resource eventGridNamespace 'Microsoft.EventGrid/namespaces@2024-06-01-preview' existing = {
  name: eventGridNamespaceName

}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(eventGridNamespace.id, principalId, roleIds[roleName])
  scope: eventGridNamespace
  properties: {
    roleDefinitionId: roleIds[roleName]
    principalId: principalId
    principalType: principalType
  }
}
