//
// PARAMETERS
//
@description('The number of CPU cores to allocate to the Valheim server (in vCPUs).')
param cpuCores int = 4

@description('The amount of memory to allocate to the Valheim server (in GB).')
param memoryInGb int = 4

@description('The name of the game - should be unique for different Valheim games.')
@minLength(4)
@maxLength(12)
param gameName string

@description('The password for the Valheim server (optional).')
@minLength(6)
@maxLength(20)
@secure()
param password string

@description('The azure location where Valheim should be hosted.')
param location string = resourceGroup().location


//
//
//
@description('Storage Account for all Game Servers')
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'gameservers${uniqueString(resourceGroup().id)}'
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

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

@description('File Share for Valheim Config')
resource fileShareConfig 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  parent: fileService
  name: 'valheim-${gameName}-config'
  properties: {
    shareQuota: 1
  }
}

@description('Contains the port mappings for the Valheim server.')
var gamePorts = [
  {
    port: 2456
    protocol: 'UDP'
  }
  {
    port: 2457
    protocol: 'UDP'
  }
]


@description('Valheim Server for Game via Container Instances')
resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: 'valheim-${gameName}'
  location: location
  properties: {
    containers: [
      {
        name: 'valheim-server-${gameName}'
        properties: {
          image: 'lacledeslan/gamesvr-valheim'
          command: ['/app/valheim_server.x86_64', '-batchmode', '-nographics', '-name', 'll-${gameName}', '-password', '${password}', '-world', 'Dedicated', '-public', '1']
          ports: gamePorts
          resources: {
            requests: {
              cpu: cpuCores
              memoryInGB: memoryInGb
            }
          }
          volumeMounts: [
            {
                name: 'config'
                mountPath: '/app/.config/unity3d/IronGate/Valheim'
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
        name: 'config'
        azureFile: {
          readOnly: false
          shareName: fileShareConfig.name
          storageAccountName: storageAccount.name
          storageAccountKey: storageAccount.listKeys().keys[0].value
        }
      }
    ]
  }
}

output containerIPv4Address string = containerGroup.properties.ipAddress.ip
