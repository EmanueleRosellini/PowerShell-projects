<# 
    Backup Azure AD (Entra ID) users via REST (Microsoft Graph)
    - Auth: client credentials (app registration)
    - Output: JSON + CSV with core account attributes
#>

# ==== CONFIGURE THESE VALUES ====
$TenantId     = "<YOUR_TENANT_ID>"
$ClientId     = "<YOUR_CLIENT_ID>"
$ClientSecret = "<YOUR_CLIENT_SECRET>"

# Graph token endpoint (v2.0)
$TokenEndpoint = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"

# Microsoft Graph scope for client credentials
$Scope = "https://graph.microsoft.com/.default"

# Output files
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupJson = ".\AAD_Users_Backup_$timestamp.json"
$backupCsv  = ".\AAD_Users_Backup_$timestamp.csv"


# ==== 1. GET ACCESS TOKEN VIA REST ====
$tokenBody = @{
    client_id     = $ClientId
    client_secret = $ClientSecret
    scope         = $Scope
    grant_type    = "client_credentials"
}

try {
    $tokenResponse = Invoke-RestMethod -Method Post -Uri $TokenEndpoint -Body $tokenBody
    $accessToken   = $tokenResponse.access_token
}
catch {
    Write-Error "Failed to get access token: $($_.Exception.Message)"
    exit 1
}

$headers = @{
    Authorization = "Bearer $accessToken"
    "Content-Type" = "application/json"
}

# ==== 2. LOOP THROUGH USERS VIA MICROSOFT GRAPH ====
# Select only the attributes you care about for backup
$select = "id,displayName,mail,userPrincipalName,accountEnabled,createdDateTime,givenName,surname,jobTitle,department"

$graphUrl = "https://graph.microsoft.com/v1.0/users`?$select=$select"

$allUsers = @()

do {
    try {
        $response = Invoke-RestMethod -Method Get -Uri $graphUrl -Headers $headers
    }
    catch {
        Write-Error "Error querying Graph: $($_.Exception.Message)"
        break
    }

    if ($response.value) {
        $allUsers += $response.value
    }

    # Handle pagination via @odata.nextLink
    $graphUrl = $response.'@odata.nextLink'
}
while ($graphUrl)

Write-Host "Total users retrieved: $($allUsers.Count)"


# ==== 3. SAVE BACKUP LOCALLY (JSON + CSV) ====
# JSON backup (full raw objects)
$allUsers | ConvertTo-Json -Depth 5 | Out-File -FilePath $backupJson -Encoding UTF8

# CSV backup (flattened)
$allUsers |
    Select-Object id,displayName,mail,userPrincipalName,accountEnabled,createdDateTime,givenName,surname,jobTitle,department |
    Export-Csv -Path $backupCsv -NoTypeInformation -Encoding UTF8

Write-Host "Backup completed."
Write-Host "JSON: $backupJson"
Write-Host "CSV : $backupCsv"
