@description('The number of CPU cores to allocate to the Factorio server (in vCPUs).')
param cpuCores int = 1

@description('The amount of memory to allocate to the Factorio server (in GB).')
param memoryInGb int = 1

@description('The name of the game - should be unique for different Factorio games.')
@minLength(4)
@maxLength(10)
param gameName string = 'freeplay'

@description('The RCON password for the Factorio server (optional).')
param rconPass string = ''

@description('The azure location where Factorio should be hosted.')
param location string = resourceGroup().location

@description('The version of the Factorio server to create.')
param factorioVersion string = 'stable'

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

/*
//For future use, in splitting bicep files apart

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' existing = {
  name: storageAccountName
}
//*/

@description('File Share for Factorio Game')
resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-09-01' = {
  name: '${storageAccount.name}/default/factorio-${gameName}-savedata'
  properties: {
    shareQuota: 1
  }
}

@description('Generate Factorio RCON password file')
resource generateRconPassword 'Microsoft.Resources/deploymentScripts@2020-10-01' = if (!empty(rconPass)) {
  name: 'script-generate-factorio-rcon-password'
  location: location
  kind:'AzureCLI'
  properties: {
    azCliVersion: '2.9.1'
    retentionInterval: 'PT1H'
    cleanupPreference: 'Always'
    environmentVariables: [
      {
        name: 'AZURE_STORAGE_ACCOUNT'
        value: storageAccount.name
      }
      {
        name: 'AZURE_STORAGE_KEY'
        secureValue: storageAccount.listKeys().keys[0].value
      }
    ]
    scriptContent: 'echo "${rconPass}" > rconpw && az storage file upload --source ./rconpw --share-name factorio-${gameName}-savedata --path \\config\\'
  }
}

@description('Contains the port mappings for the Factorio server.')
var gamePorts = empty(rconPass) ? [
  {
    port: 34197
    protocol: 'UDP'
  }
] : [
  {
    port: 27015
    protocol: 'TCP'
  }
  {
    port: 34197
    protocol: 'UDP'
  }
]


@description('Factorio Server for Game via Container Instances')
resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2021-09-01' = {
  name: 'factorio-${gameName}'
  location: location
  properties: {
    containers: [
      {
        name: 'factorio-server-${gameName}'
        properties: {
          image: 'factoriotools/factorio:${factorioVersion}'
          environmentVariables:[
            {
              name: 'GENERATE_NEW_SAVE'
              value: 'true'
            }
            {
              name: 'SAVE_NAME'
              value: 'save-${gameName}'
            }
          ]
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
                mountPath: '/factorio'
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
          shareName: 'factorio-${gameName}-savedata'
          storageAccountName: storageAccount.name
          storageAccountKey: storageAccount.listKeys().keys[0].value
        }
      }
    ]
  }
}


output containerIPv4Address string = containerGroup.properties.ipAddress.ip
output rcon string = rconPass
