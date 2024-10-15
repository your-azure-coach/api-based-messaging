// Scope
targetScope = 'resourceGroup'

// Parameters
param name string
param location string = resourceGroup().location
param sku string
param publisherName string
param publisherEmail string

// Describe API Management service
resource apiManagementService 'Microsoft.ApiManagement/service@2021-12-01-preview' = {
  name: name
  location: location
  sku: {
    name: sku
    capacity: sku == 'Consumption' ? 0 : 1
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    notificationSenderEmail: publisherEmail
    publicNetworkAccess: 'Enabled'
  }
}

// Describe outputs
output name string = name
output principalId string = apiManagementService.identity.principalId
