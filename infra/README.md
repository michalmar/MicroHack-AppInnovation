# Azure SQL Serverless Bicep

This folder contains a Bicep template to deploy an Azure SQL logical server and a single serverless database.

Files
- `main.bicep` - Deploys the SQL server, a firewall rule allowing a single IP, and a serverless database (General Purpose, Gen5).
- `parameters.dev.bicepparam` - Example parameters file showing how to provide values (example uses Key Vault reference for password).

How to deploy

1. Edit `parameters.dev.bicepparam` and replace placeholder values (`<sub>`, `<rg>`, `<vault-name>`) or provide parameters inline during deployment.
2. Deploy to an existing resource group using the Azure CLI:

```powershell
az deployment group create --resource-group <your-rg> --template-file .\bicep\main.bicep --parameters .\bicep\parameters.dev.bicepparam
```

Notes and assumptions
- The template derives `location` from the resource group by default.
- The SQL server name is generated using `uniqueString(resourceGroup().id)` to ensure uniqueness.
- The `adminPassword` parameter is marked `@secure()` in the template; using a Key Vault reference in the parameters file is recommended.
- The database is configured as serverless with `autoPauseDelay` set to 60 (minutes), `minCapacity` 0.5 and `sku.capacity` set to 2 (max vCores). Adjust values to suit your needs and region.

References
- Bicep resource reference: Microsoft.Sql/servers and Microsoft.Sql/servers/databases
- Serverless overview: Azure SQL Database serverless tier
