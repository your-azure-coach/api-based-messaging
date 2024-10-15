//Define scope
targetScope = 'resourceGroup'

//Define parameters
param apiManagementName string
param eventGridNamespaceName string
param eventGridTopicName string = 'messages'
param storageAccountName string
param rbacConfigBlobName string
param rbacConfigRefreshInterval int = 5
param apiId string = 'messaging-api'
param apiDisplayName string = 'Messaging API'
param apiVersion string = 'v1'
param apiPath string = apiId
param maxDeliveryCount int = 1
param receiveLockDuration int = 60

// Configure Message Schemas
var messageTypes = [
  {
    name: 'header.v1'
    content: loadJsonContent('../02_sample/schemas/common/header.v1.json')
    publishAsOperation: false
  }
  {
    name: 'customer.onboarded.v1'
    content: loadJsonContent('../02_sample/schemas/events/customer.onboarded.v1.json')
    publishAsOperation: true
  }
  {
    name: 'invoice.booked.v1'
    content: loadJsonContent('../02_sample/schemas/events/invoice.booked.v1.json')
    publishAsOperation: true
  }
  {
    name: 'project.won.v1'
    content: loadJsonContent('../02_sample/schemas/events/project.won.v1.json')
    publishAsOperation: true
  }
]

// Get Schemas
var schemas = reduce(messageTypes, {}, (cur, next) => union(cur, {
  '${next.name}': next.content
}))

// Get MessageTypes to publish
var messageTypesToPublishArray = [for (item, i) in messageTypes:item.publishAsOperation == true ? item : []]
var messageTypesToPublish = map(intersection(messageTypes, messageTypesToPublishArray), mt => mt.name )

// Reference existing Event Grid Namespace
resource eventGridNamespace 'Microsoft.EventGrid/namespaces@2024-06-01-preview' existing = {
  name: eventGridNamespaceName
}

// Describe Event Grid topic
resource eventGridTopic 'Microsoft.EventGrid/namespaces/topics@2024-06-01-preview' = {
  name: eventGridTopicName
  parent: eventGridNamespace
  properties: {
    inputSchema: 'CloudEventSchemaV1_0'
    publisherType: 'Custom'
  }
}

// Describe named values
module namedValues 'modules/api-management-named-values.bicep' = {
  name: 'named-values'
  params: {
    apimName: apiManagementName
    namedValues: {
      'messaging-api-topic-name' : eventGridTopicName
      'messaging-api-eventgrid-url' : 'https://${eventGridNamespace.properties.topicsConfiguration.hostname}'
      'messaging-api-default-openid-config-url' : 'https://login.microsoftonline.com/${tenant().tenantId}/v2.0/.well-known/openid-configuration'
      'messaging-api-default-audience' : environment().resourceManager
      'messaging-api-default-issuer' : 'https://sts.windows.net/${tenant().tenantId}/'
      'messaging-api-storage-account-name' : storageAccountName
      'messaging-api-rbac-config-blob-name' : rbacConfigBlobName
      'messaging-api-rbac-config-refresh-interval' : '${rbacConfigRefreshInterval}'
      'messaging-api-max-delivery-count' : '${maxDeliveryCount}'
      'messaging-api-receive-lock-duration' : '${receiveLockDuration}'
      'messaging-api-event-grid-namespace-id' : eventGridNamespace.id
    }
  }
}

// Describe Messaging API
module api './modules/api-management-api.bicep' = {
  name: 'apim-messaging-api'
  params: {
    apimName: apiManagementName
    displayName: apiDisplayName
    id: apiId
    version: apiVersion
    path: apiPath
    requiresSubscription: false
    subscriptionKeyName: 'api-key'
    type: 'openapi'
    protocols: [
      'https'
    ]
    policyXml: loadTextContent('policies/api.xml')
  }
  dependsOn: [
    namedValues
  ]
}

//Upload API schemas
module apiSchemas 'modules/api-management-api-schemas.bicep' = {
  name: 'apim-messaging-api-schemas'
  params: {
    apimName: apiManagementName
    apiName: api.outputs.name
    schemas: schemas
  }
  dependsOn: [ api ]
}


//Describe Publish Operations
module publishOperations 'modules/api-management-api-operation.bicep' = [for (messageType, i) in messageTypesToPublish: {
  name: 'apim-publish-${messageType}'
  params: {
    id: '${replace(messageType, '.', '-')}-publish'
    apiName: api.outputs.name
    apimName: apiManagementName
    displayName: 'Publish message ${messageType}'
    httpMethod: 'POST'
    urlTemplate: 'message/${messageType}/publish'
    requestSchemaName: messageType
    policyXml: replace(replace(loadTextContent('policies/publish-operation.xml'), '##message-type##', messageType), '##subscription-name##', replace(messageType, '.', '-'))
    tags: [ messageType ]
  }
  dependsOn: [ apiSchemas ]
}]

//Describe Subscribe Operations
module subscribeOperations 'modules/api-management-api-operation.bicep' = [for (messageType, i) in messageTypesToPublish: {
  name: 'apim-subscribe-${messageType}'
  params: {
    id: '${replace(messageType, '.', '-')}-subscribe'
    apiName: api.outputs.name
    apimName: apiManagementName
    displayName: 'Subscribe message ${messageType}'
    httpMethod: 'POST'
    urlTemplate: 'message/${messageType}/subscribe'
    policyXml: replace(replace(loadTextContent('policies/subscribe-operation.xml'), '##message-type##', messageType), '##subscription-name##', replace(messageType, '.', '-'))
    tags: [ messageType ]
  }
  dependsOn: [ apiSchemas ]
}]

//Describe Unsubscribe Operations
module unsubscribeOperations 'modules/api-management-api-operation.bicep' = [for (messageType, i) in messageTypesToPublish: {
  name: 'apim-unsubscribe-${messageType}'
  params: {
    id: '${replace(messageType, '.', '-')}-unsubscribe'
    apiName: api.outputs.name
    apimName: apiManagementName
    displayName: 'Unsubscribe message ${messageType}'
    httpMethod: 'POST'
    urlTemplate: 'message/${messageType}/unsubscribe'
    policyXml: replace(replace(loadTextContent('policies/unsubscribe-operation.xml'), '##message-type##', messageType), '##subscription-name##', replace(messageType, '.', '-'))
    tags: [ messageType ]
  }
  dependsOn: [ apiSchemas ]
}]

//Describe Receive Operations
module receiveOperations 'modules/api-management-api-operation.bicep' = [for (messageType, i) in messageTypesToPublish: {
  name: 'apim-receive-${messageType}'
  params: {
    id: '${replace(messageType, '.', '-')}-receive'
    apiName: api.outputs.name
    apimName: apiManagementName
    displayName: 'Receive message ${messageType}'
    httpMethod: 'GET'
    urlTemplate: 'message/${messageType}/receive'
    responseSchemaName: messageType
    responseHeaders: [ 'X-MessagingApi-MessageToken' ]
    policyXml: replace(replace(loadTextContent('policies/receive-operation.xml'), '##message-type##', messageType), '##subscription-name##', replace(messageType, '.', '-'))
    tags: [ messageType ]
  }
  dependsOn: [ apiSchemas ]
}]

//Describe Acknowledge Operations
module acknowledgeOperations 'modules/api-management-api-operation.bicep' = [for (messageType, i) in messageTypesToPublish: {
  name: 'apim-acknowledge-${messageType}'
  params: {
    id: '${replace(messageType, '.', '-')}-acknowledge'
    apiName: api.outputs.name
    apimName: apiManagementName
    displayName: 'Acknowledge message ${messageType}'
    httpMethod: 'GET'
    urlTemplate: 'message/${messageType}/acknowledge'
    queryParameters: [ 'messageToken' ]
    policyXml: replace(replace(loadTextContent('policies/acknowledge-operation.xml'), '##message-type##', messageType), '##subscription-name##', replace(messageType, '.', '-'))
    tags: [ messageType ]
  }
  dependsOn: [ apiSchemas ]
}]

//Describe List Operations
module listOperation 'modules/api-management-api-operation.bicep' = {
  name: 'apim-manage-list'
  params: {
    id: 'manage-list'
    apiName: api.outputs.name
    apimName: apiManagementName
    displayName: 'List subscriptions'
    httpMethod: 'GET'
    urlTemplate: 'subscriptions'
    policyXml: loadTextContent('policies/list-operation.xml')
    tags: [ 'mgmt' ]
  }
  dependsOn: [ apiSchemas ]
}
