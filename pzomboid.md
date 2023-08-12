# Bicep Template for Running a Project Zomboid Server in Azure Container Instances

## Start/Create

```powershell
az group create --name game-servers --location centralus
az deployment group create --resource-group game-servers --template-file ./pzomboid.bicep --parameters location=centralus gameName=freeplay adminPassword=setMe
```
