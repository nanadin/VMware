<#
.SYNOPSIS
    Generates a basic inventory report of all VMs in a vCenter environment.
.DESCRIPTION
    This script connects to a specified vCenter server, collects key details 
    (Name, Power State, CPU, Memory, and Host) for all virtual machines, 
    and exports the results to a CSV file.
.NOTES
    Author: Your Name
    Prerequisites: VMware.PowerCLI module installed.
#>

# --- Configuration Variables ---
$vCenterServer = "vc.551aee9c52c94651bf961c.westus.avs.azure.com" # Change to your vCenter FQDN or IP
$ExportPath    = "C:\GitHub\Scripts\vCenter_VM_Report.csv"

# --- 1. Ensure PowerCLI Module is Loaded ---
if (-not (Get-Module -Name VMware.PowerCLI -ListAvailable)) {
    Write-Error "VMware.PowerCLI module is not installed. Run 'Install-Module VMware.PowerCLI' first."
    exit
}

# --- 2. Connect to vCenter ---
Write-Host "Connecting to vCenter: $vCenterServer..." -ForegroundColor Cyan
try {
    # Suppress invalid certificate warnings if your lab uses self-signed certs
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
    
    Connect-VIServer -Server $vCenterServer -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to vCenter. Reason: $_"
    exit
}

# --- 3. Gather VM Data and Export ---
Write-Host "Gathering VM inventory..." -ForegroundColor Yellow

# Fetching the VMs and selecting specific properties
$VMReport = Get-VM | Select-Object Name, 
                                   PowerState, 
                                   NumCpu, 
                                   MemoryGB, 
                                   @{Name="ESXiHost"; Expression={$_.VMHost.Name}}

# Exporting data to CSV
if ($VMReport) {
    $VMReport | Export-Csv -Path $ExportPath -NoTypeInformation -Force
    Write-Host "Success! Report exported to: $ExportPath" -ForegroundColor Green
} else {
    Write-Warning "No virtual machines found or unable to retrieve data."
}

# --- 4. Disconnect Cleanly ---
Write-Host "Disconnecting from vCenter..." -ForegroundColor Cyan
Disconnect-VIServer -Server $vCenterServer -Confirm:$false