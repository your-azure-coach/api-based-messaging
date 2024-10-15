// Scope
targetScope = 'resourceGroup'

param id string
param displayName string
param apiName string
param apimName string
param httpMethod string
param urlTemplate string
param urlTemplateParameters string[] = []
param queryParameters string[] = []
param requestSchemaName string = ''
param requestHeaders string[] = []
param responseSchemaName string = ''
param responseHeaders string[] = []
param policyXml string = ''
param tags string[] = []

var schemaId = 'schema'

// Refer to existing resources
resource apiManagement 'Microsoft.ApiManagement/service@2022-04-01-preview' existing = {
  name: apimName
}

resource api 'Microsoft.ApiManagement/service/apis@2022-04-01-preview' existing = {
  name: apiName
  parent: apiManagement
}


// Describe API operation
resource operation 'Microsoft.ApiManagement/service/apis/operations@2022-04-01-preview' = {
  name: id
  parent: api
  properties: {
    displayName: displayName
    method: httpMethod
    urlTemplate: urlTemplate
    templateParameters: [ for parameter in urlTemplateParameters : {
        name: parameter
        required: true
        type: 'string'
      }
    ]
    request : {
      representations: (empty(requestSchemaName)) ? null : [
        {
          contentType: 'application/json'
          schemaId: schemaId
          typeName: requestSchemaName
        }
      ]
      headers: [ for requestHeader in requestHeaders : {
          name: requestHeader
          required: true
          type: 'string'
        }
      ]
      queryParameters: [ for queryParameter in queryParameters : {
          name: queryParameter
          required: true
          type: 'string'
        }
      ]
    } 
    responses: [
      {
        statusCode: 200
        representations: (empty(responseSchemaName)) ? null : [
          {
            contentType: 'application/json'
            schemaId: schemaId
            typeName: responseSchemaName
          }
        ]
        headers: [ for responseHeader in responseHeaders : {
          name: responseHeader
          required: true
          type: 'string'
        }
      ]
      }
    ]
  }
}

// Describe API operation policy
resource operationPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2022-04-01-preview' = if(policyXml != '') {
  name: 'policy'
  parent: operation
  properties: {
    value: policyXml
    format:  'rawxml'
  }
}

// Describe API Management tags
resource apimTags 'Microsoft.ApiManagement/service/tags@2023-05-01-preview' = [for tag in tags : {
  name: replace(tag, '.', '-')
  parent: apiManagement
  properties: {
    displayName: tag
  }
}]

// Describe API Operation tags
resource operationTags 'Microsoft.ApiManagement/service/tags/operationLinks@2023-05-01-preview' = [for (tag, n) in tags : {
  name: '${apiName}-${operation.name}-${replace(tag, '.', '-')}'
  parent: apimTags[n]
  properties: {
    operationId: operation.id
  }
}]
