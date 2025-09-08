using './main.bicep'

// Azure region for all resources (defaults to this value if not overridden)
param location = 'swedencentral'

// Administrator login for the SQL server
param adminLogin = 'lego_app'

// IMPORTANT: Replace with secure value or leverage Key Vault at deployment time.
// For local testing ONLY. Do not commit real credentials.
param adminPassword = 'Azure12345678'

// IPv4 address of the application to whitelist (single IP)
param appIp = '135.225.28.97'

// Database name
param databaseName = 'LegoCatalog'

