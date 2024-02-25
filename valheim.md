# Bicep Template for Running a Valheim Server in Azure Container Instances

## Start/Create

```powershell
az group create --name game-servers --location centralus
az deployment group create --resource-group game-servers --template-file ./valheim.bicep --parameters location=centralus gameName=freeplay password=PASSWORD
```
