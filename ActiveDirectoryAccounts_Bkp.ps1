<#
    Backup all AD user identities and their attributes to CSV
    - On-prem Microsoft Active Directory
    - Requires: RSAT / ActiveDirectory PowerShell module
#>

try {
    Import-Module ActiveDirectory -ErrorAction Stop
}
catch {
    Write-Error "ActiveDirectory module not found. Please install RSAT / AD PowerShell tools."
    exit 1
}

# ==== CONFIGURATION ====

# Optional: specify a DC (or leave $null to let AD choose automatically)
$DomainController = $null   # e.g. "dc01.contoso.local"

# Optional: search base (or leave $null for the whole domain)
$SearchBase = $null         # e.g. "OU=Users,DC=contoso,DC=local"

# Output file
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outputCsv = ".\AD_AllUsers_FullBackup_$timestamp.csv"

Write-Host "Starting full AD users backup..."
Write-Host "This may take a while depending on domain size."

# ==== BUILD SEARCH PARAMETERS ====

$searchParams = @{
    Filter        = "*"
    Properties    = "*"       # all available attributes
    ResultSetSize = $null     # no limit
    Server        = $DomainController
}

if ($SearchBase) {
    $searchParams["SearchBase"] = $SearchBase
}

# ==== QUERY AD ====

try {
    $users = Get-ADUser @searchParams
}
catch {
    Write-Error "Failed to query Active Directory: $($_.Exception.Message)"
    exit 1
}

Write-Host "Total users retrieved: $($users.Count)"

if (-not $users -or $users.Count -eq 0) {
    Write-Warning "No users found. Exiting."
    exit 0
}

# ==== EXPORT TO CSV ====
# Select-Object * ensures all properties on the ADUser objects are included

try {
    $users |
        Select-Object * |
        Export-Csv -Path $outputCsv -NoTypeInformation -Encoding UTF8

    Write-Host "Backup completed successfully."
    Write-Host "CSV saved to: $outputCsv"
}
catch {
    Write-Error "Failed to export to CSV: $($_.Exception.Message)"
    exit 1
}
