@description('The number of CPU cores to allocate to the Colony Survival server (in vCPUs).')
param cpuCores int = 4

@description('The amount of memory to allocate to the Colony Survival server (in GB).')
param memoryInGb int = 8

@description('The name of the game - should be unique for different Colony Survival games.')
@minLength(4)
@maxLength(16)
param gameName string

@description('The password to join the game')
@minLength(4)
@maxLength(16)
@secure()
param gamePass string

@description('The azure location where Colony Survival should be hosted.')
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

@description('File Share for Colony Survival Game')
resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-09-01' = {
  parent: fileServices
  name: 'colonysurvival-${gameName}'
  properties: {
    shareQuota: 1
  }
}

@description('Contains the port mappings for the Colony Survival server.')
var gamePorts = [
  {
    port: 3478
    protocol: 'UDP'
  }
  {
    port: 4379
    protocol: 'UDP'
  }
  {
    port: 4380
    protocol: 'UDP'
  }
  {
    port: 27004
    protocol: 'UDP'
  }
  {
    port: 27005
    protocol: 'TCP'
  }
  {
    port: 27016
    protocol: 'UDP'
  }
  {
    port: 27017
    protocol: 'UDP'
  }
  {
    port: 27018
    protocol: 'UDP'
  }
]

@description('Colony Survival Server for Game via Container Instances')
resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2021-09-01' = {
  name: 'colonysurvival-${gameName}'
  location: location
  properties: {
    containers: [
      {
        name: 'colonysurvival-server-${gameName}'
        properties: {
          image: 'lacledeslan/gamesvr-colonysurvival:latest'
          command: ['/app/colonyserver.x86_64', '-batchmode', '-nographics', '-nosound', '+server.networktype', 'SteamOnline', '+server.password', '${gamePass}', '+server.name', '"LL ${gameName}"', '+server.world', '"ll-${gameName}"' ]
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
                mountPath: '/app/.local/share/Pipliz/Colony Survival/Servers/'
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
          shareName: 'colonysurvival-${gameName}'
          storageAccountName: storageAccount.name
          storageAccountKey: storageAccount.listKeys().keys[0].value
        }
      }
    ]
  }
}


output containerIPv4Address string = containerGroup.properties.ipAddress.ip
