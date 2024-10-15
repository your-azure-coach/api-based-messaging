
param name string
param location string

resource eventGridNamespace 'Microsoft.EventGrid/namespaces@2024-06-01-preview' = {
  name: name
  location: location
  sku: {
    name: 'Standard'
  }
  identity: {
    type: 'SystemAssigned'
  }
}


// Describe outputs
output name string = name
output principalId string = eventGridNamespace.identity.principalId
