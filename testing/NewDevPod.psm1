<#
PowerShell script for deploying a development environment on vSphere.
The script creates the following: 1 Port Group, 1 vApp, 1 pfSense
Author: Evan Deters
#>

function New-DevPod {

    param(
        [Parameter(Mandatory=$true)]
        [String] $Name,
        [Parameter(Mandatory=$true)]
        [String] $Target,
        [Boolean] $CreateRouter,
        [String] $WanPortGroup,
        [String[]] $Boxes
    )

    # Creates the Dev Port Group, vApp, and Router
    $DevPortGroup = New-PodPortGroups -Portgroups 1 -StartPort 1300 -EndPort 1350
    New-VApp -Location $Target -Name $Name
    if($CreateRouter -eq $true) {
        New-PodRouter -Target $Name -WanPortGroup $WanPortGroup -LanPortGroup $DevPortGroup[1].name
    }
    if($Boxes.Count -ne 0) {
        for ($i = 0; $i -lt $Boxes.Count; $i++) {
            New-VM -Name $Boxes[$i] `
             -ResourcePool (Get-VApp -Name $Name) `
             -Datastore (Get-DataStore -Name Ursula) `
             -Template (Get-Template -Name $Boxes[$i])
            Get-VM -Name $Boxes[$i] | Get-NetworkAdapter -Name "Network adapter 1" | Set-NetworkAdapter -Portgroup (Get-VDPortgroup -Name $DevPortGroup[1].name) -Confirm:$false
        }
    }
}

# Creates a pfSense Router for the vApp 
function New-PodRouter {

    param (
        [Parameter(Mandatory=$true)]
        [String] $Target,
        [Parameter(Mandatory=$true)]
        [String] $WanPortGroup,
        [Parameter(Mandatory=$true)]
        [String] $LanPortGroup
    )

    # Creating the Router
    New-VM -Name $LanPortGroup'_PodRouter' `
     -ResourcePool (Get-VApp -Name $Target) `
     -Datastore (Get-DataStore -Name Ursula) `
     -Template (Get-Template -Name "pfSenseBlank")

    # Assigning port groups to the interfaces
    Get-VM -Name $LanPortGroup'_PodRouter' | Get-NetworkAdapter -Name "Network adapter 1" | Set-NetworkAdapter -Portgroup (Get-VDPortgroup -Name $WanPortGroup) -Confirm:$false
    Get-VM -Name $LanPortGroup'_PodRouter' | Get-NetworkAdapter -Name "Network adapter 2" | Set-NetworkAdapter -Portgroup (Get-VDPortgroup -Name $LanPortGroup) -Confirm:$false
} 
