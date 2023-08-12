@description('The number of CPU cores to allocate to the Project Zomboid server (in vCPUs).')
param cpuCores int = 4

@description('The amount of memory to allocate to the Project Zomboid server (in GB).')
param memoryInGb int = 8

@description('The name of the game - should be unique for different Project Zomboid games.')
@minLength(4)
@maxLength(16)
param gameName string

@description('The password to admin the game')
@minLength(8)
@maxLength(16)
@secure()
param adminPassword string

@description('The azure location where Project Zomboid should be hosted.')
param location string = resourceGroup().location

var storageAccountName = 'gameservers${uniqueString(resourceGroup().id)}'

@description('Storage Account for all Game Servers')
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    allowBlobPublicAccess: false
    accessTier: 'Hot'
  }
}

@description('File Share for all Game Servers')
resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2021-09-01' existing = {
  parent: storageAccount
  name: 'default'
}

@description('File Share for Project Zomboid Game')
resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-09-01' = {
  parent: fileServices
  name: 'pzomboid-${gameName}'
  properties: {
    shareQuota: 1
  }
}

@description('Contains the port mappings for the Project Zomboid server.')
var gamePorts = [
  {
    port: 16261
    protocol: 'UDP'
  }
  {
    port: 16262
    protocol: 'UDP'
  }
]

@description('Project Zomboid Server for Game via Container Instances')
resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2021-09-01' = {
  name: 'pzomboid-${gameName}'
  location: location
  properties: {
    containers: [
      {
        name: 'pzomboid-server-${gameName}'
        properties: {
          image: 'lacledeslan/gamesvr-pzomboid:latest'
          command: ['/app/start-server.sh', '-adminpassword', '${adminPassword}', '-servername', '${gameName}' ]
          environmentVariables:[]
          ports: gamePorts
          resources: {
            requests: {
              cpu: cpuCores
              memoryInGB: memoryInGb
            }
          }
          volumeMounts: [
            {
                name: 'savedata'
                mountPath: '/app/Zomboid/'
                readOnly: false
            }
          ]
        }
      }
    ]
    osType: 'Linux'
    restartPolicy: 'OnFailure'
    ipAddress: {
      type: 'Public'
      ports: gamePorts
    }
    volumes: [
      {
        name: 'savedata'
        azureFile: {
          readOnly: false
          shareName: 'pzomboid-${gameName}'
          storageAccountName: storageAccount.name
          storageAccountKey: storageAccount.listKeys().keys[0].value
        }
      }
    ]
  }
}


output containerIPv4Address string = containerGroup.properties.ipAddress.ip
