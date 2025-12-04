<# 
.SYNOPSIS
  Export on-prem AD account data (users, groups, computers) to CSV files for backup/DR.

.DESCRIPTION
  - Connects to the local on-prem Active Directory (requires RSAT / ActiveDirectory module).
  - Exports:
      * All users
      * All groups
      * All computers
  - Includes all attributes available through -Properties * (may be large).
  - Writes timestamped CSVs to the specified output folder.

.NOTES
  - Run from an elevated PowerShell session with an account that can read AD.
  - This is NOT a full AD backup (no passwords, ACLs on objects in a restorable form, 
    SYSVOL, etc.). Use proper AD-aware backup tools for real DR.
#>

[CmdletBinding()]
param(
    # Where to store the CSV files
    [Parameter(Mandatory = $false)]
    [string]$OutputFolder = "C:\AD_Exports",

    # Optional: domain controller to target explicitly (otherwise use default)
    [Parameter(Mandatory = $false)]
    [string]$Server
)

Write-Host "=== AD Export Script Started ===" -ForegroundColor Cyan

# Ensure the ActiveDirectory module is available
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error "ActiveDirectory module not found. Install RSAT / AD tools first."
    exit 1
}

Import-Module ActiveDirectory -ErrorAction Stop

# Create output directory if needed
if (-not (Test-Path -Path $OutputFolder)) {
    Write-Host "Creating output folder: $OutputFolder"
    New-Item -ItemType Directory -Path $OutputFolder | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Helper: build common params for AD cmdlets (allows optional Server parameter)
$adParams = @{}
if ($Server) {
    Write-Host "Using domain controller: $Server"
    $adParams["Server"] = $Server
}

### Export Users ###
try {
    Write-Host "Exporting AD Users..." -ForegroundColor Yellow

    $usersOutputPath = Join-Path $OutputFolder "AD_Users_$timestamp.csv"

    Get-ADUser @adParams -Filter * -Properties * -ResultSetSize $null |
        Select-Object * |
        Export-Csv -Path $usersOutputPath -NoTypeInformation -Encoding UTF8

    Write-Host "Users exported to: $usersOutputPath" -ForegroundColor Green
}
catch {
    Write-Error "Failed to export users: $_"
}

### Export Groups ###
try {
    Write-Host "Exporting AD Groups..." -ForegroundColor Yellow

    $groupsOutputPath = Join-Path $OutputFolder "AD_Groups_$timestamp.csv"

    Get-ADGroup @adParams -Filter * -Properties * -ResultSetSize $null |
        Select-Object * |
        Export-Csv -Path $groupsOutputPath -NoTypeInformation -Encoding UTF8

    Write-Host "Groups exported to: $groupsOutputPath" -ForegroundColor Green
}
catch {
    Write-Error "Failed to export groups: $_"
}

### Export Computers ###
try {
    Write-Host "Exporting AD Computers..." -ForegroundColor Yellow

    $computersOutputPath = Join-Path $OutputFolder "AD_Computers_$timestamp.csv"

    Get-ADComputer @adParams -Filter * -Properties * -ResultSetSize $null |
        Select-Object * |
        Export-Csv -Path $computersOutputPath -NoTypeInformation -Encoding UTF8

    Write-Host "Computers exported to: $computersOutputPath" -ForegroundColor Green
}
catch {
    Write-Error "Failed to export computers: $_"
}

Write-Host "=== AD Export Script Completed ===" -ForegroundColor Cyan
