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
        [String] $WanPortGroup
    )

    # Gets the list of existing port groups in the 1300-1400 range
    $PortGroupList = Get-VDPortgroup -VDSwitch Main_DSW | Select-Object -ExpandProperty name | Sort-Object
    $PortGroupList = $PortGroupList | 
        ForEach-Object {
            [int]$PortGroupList[$PortGroupList.indexOf($_)].Substring(0, $PortGroupList[$PortGroupList.indexOf($_)].indexOf('_'))
        }
    $PortGroupList = $PortGroupList.where{$_ -IN 1300..1399}

    # Selects the first available port group
    for($i = 1300; $i -lt 1400; $i++) {
        if($PortGroupList.length -eq 0) {
            $DevPortGroup = $i
            break
        } elseif($PortGroupList.IndexOf($i) -eq -1) {
            $DevPortGroup = $i
            break
    }
}

    # Creates the Dev Port Group, vApp, and Router
    New-VDPortgroup -VDSwitch Main_DSW -Name $DevPortGroup'_DevPod' -VlanId $DevPortGroup
    New-VApp -Location $Target -Name $Name
    if($CreateRouter -eq $true) {
        New-PodRouter -Target $Name -WanPortGroup $WanPortGroup -LanPortGroup $DevPortGroup
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
        [int] $LanPortGroup
    )

    # Creating the Router
    New-VM -Name $LanPortGroup'_PodRouter' `
     -ResourcePool (Get-VApp -Name $Target) `
     -Datastore (Get-DataStore -Name Ursula) `
     -Template (Get-Template -Name "pfSense Template")

    # Assigning port groups to the interfaces
    Get-VM -Name $LanPortGroup'_PodRouter' | Get-NetworkAdapter -Name "Network adapter 1" | Set-NetworkAdapter -Portgroup (Get-VDPortgroup -Name $WanPortGroup) -Confirm:$false
    Get-VM -Name $LanPortGroup'_PodRouter' | Get-NetworkAdapter -Name "Network adapter 2" | Set-NetworkAdapter -Portgroup (Get-VDPortgroup -Name $LanPortGroup'_DevPod') -Confirm:$false
} 