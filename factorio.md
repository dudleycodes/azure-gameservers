# Bicep Template for Running a Factorio Server in Azure Container Instances

## Start/Create

```powershell
az group create --name game-servers --location centralus
az deployment group create --resource-group game-servers --template-file ./factorio.bicep --parameters location=centralus gameName=freeplay
```

## Usage

| Action              | Azure CLI Command |
| :------------------ | :---------------- |
| View container logs | `az container logs --resource-group game-servers --name factorio-{gameName}`
| Stop container      | `az container stop --resource-group game-servers --name factorio-{gameName}`
| Start container     | `az container start --resource-group game-servers --name factorio-{gameName}`
| Delete container    | `az container delete -y --resource-group game-servers --name factorio-{gameName}`

## Nuke Everything

> ⚠️⚠️⚠️ This will delete everything, include the server saves! ⚠️⚠️⚠️

```powershell
az group delete -y --name game-servers
```

## TODOs

- Split into bicep modules.
