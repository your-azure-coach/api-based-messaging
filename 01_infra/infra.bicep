targetScope = 'resourceGroup'

param location string = 'westeurope'
param apiManagementName string
param apiManagementSku string
param apiManagementPublisherName string
param apiManagementPublisherEmail string
param storageAccountName string
@allowed([
  'Premium_LRS'
  'Premium_ZRS'
  'Standard_GRS'
  'Standard_GZRS'
  'Standard_LRS'
  'Standard_RAGRS'
  'Standard_RAGZRS'
  'Standard_ZRS'
])
param storageAccountSku string
param eventGridNamespaceName string

// Create API Management
module apiManagement 'modules/api-management.bicep' = {
  name: apiManagementName
  params: {
    name: apiManagementName
    sku: apiManagementSku
    publisherName: apiManagementPublisherName
    publisherEmail: apiManagementPublisherEmail
    location: location
  }
}

// Create storage account
module storageAccount 'modules/storage-account.bicep' = {
  name: storageAccountName
  params: {
    sku: storageAccountSku
    name: storageAccountName
    location: location
    allowPublicAccess: true
  }
}

// Create event grid namespace
module eventGridNamespace 'modules/event-grid-namespace.bicep' = {
  name: eventGridNamespaceName
  params: {
    name: eventGridNamespaceName
    location: location
  }
}

// Grant Event Grid rights on Storage Account (for deadlettering)
module eventGridToStorageAccountRole 'modules/role-assignment-storage-account.bicep' = {
  name: 'eventGridToStorageAccountRole'
  params: {
    storageAccountName: storageAccount.outputs.name
    principalType: 'ServicePrincipal'
    principalId: eventGridNamespace.outputs.principalId
    roleName: 'Storage Blob Data Contributor'
  }
}

// Grant API Management rights on Storage Account (for reading RBAC config)
module apiManagementToStorageAccountRole 'modules/role-assignment-storage-account.bicep' = {
  name: 'apiManagementToStorageAccountRole'
  params: {
    storageAccountName: storageAccount.outputs.name
    principalType: 'ServicePrincipal'
    principalId: apiManagement.outputs.principalId
    roleName: 'Storage Blob Data Reader'
  }
}

// Grant API Management rights on Event Grid Namespace (for managing subscriptions)
module apiManagementToEventGridNamespaceMgmtRole 'modules/role-assignment-event-grid-namespace.bicep' = {
  name: 'apiManagementToEventGridNamespaceMgmtRole'
  params: {
    eventGridNamespaceName: eventGridNamespace.outputs.name
    principalType: 'ServicePrincipal'
    principalId: apiManagement.outputs.principalId
    roleName: 'EventGrid Contributor'
  }
}

// Grant API Management rights on Event Grid Namespace (for sending messages)
module apiManagementToEventGridNamespaceSenderRole 'modules/role-assignment-event-grid-namespace.bicep' = {
  name: 'apiManagementToEventGridNamespaceSenderRole'
  params: {
    eventGridNamespaceName: eventGridNamespace.outputs.name
    principalType: 'ServicePrincipal'
    principalId: apiManagement.outputs.principalId
    roleName:  'EventGrid Data Sender'
  }
}

// Grant API Management rights on Event Grid Namespace (for receiving messages)
module apiManagementToEventGridNamespaceReaderRole 'modules/role-assignment-event-grid-namespace.bicep' = {
  name: 'apiManagementToEventGridNamespaceReaderRole'
  params: {
    eventGridNamespaceName: eventGridNamespace.outputs.name
    principalType: 'ServicePrincipal'
    principalId: apiManagement.outputs.principalId
    roleName:  'EventGrid Data Receiver'
  }
}
