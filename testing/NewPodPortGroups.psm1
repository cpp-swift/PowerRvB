<#
Creates a specified amount of port groups using the lowest available numbers
Author: Evan Deters
#>

function New-PodPortGroups {

    param(
        [ValidateRange(1,50)]
        [Parameter(Mandatory=$true)]
        [int] $Portgroups,
        [Parameter(Mandatory=$true)]
        [ValidateRange(1000,1350)]
        [int] $StartPort,
        [Parameter(Mandatory=$true)]
        [ValidateRange(1000,1350)]
        [int] $EndPort
    )

    $ErrorActionPreference = "Stop"

    # Gets the list of existing port groups in the range
    $PortGroupList = Get-VDPortgroup -VDSwitch Main_DSW | Select-Object -ExpandProperty name | Sort-Object
    $PortGroupList = $PortGroupList | 
        ForEach-Object {
            [int]$PortGroupList[$PortGroupList.indexOf($_)].Substring(0, $PortGroupList[$PortGroupList.indexOf($_)].indexOf('_'))
        }
    $PortGroupList = $PortGroupList.where{$_ -IN $StartPort..$EndPort}
    
    # Check if Port Groups can be created
    if($EndPort - $StartPort - $PortGroupList.Count + 1 -lt $Portgroups) {
        $temp = $EndPort - $StartPort - $PortGroupList.Count + 1
        Write-Error -Message "There are not enough port groups available in this range. Only $temp can be created."
    }

    # Creates the port groups
    $j = $StartPort
    $i = 0
    [int[]]$CreatedPortGroups
    While ($i -le $Portgroups - 1) {
        if($PortGroupList.IndexOf($j) -ne -1) { $j++; continue }
        if($j -gt $EndPort) { Write-Error -Message "There are no more available port groups in the specified range."}
        else {
            $PodPortGroup = $j
            New-VDPortgroup -VDSwitch Main_DSW -Name $PodPortGroup'_PodNetwork' -VlanId $PodPortGroup
            $CreatedPortGroups += $j
            $j++
            $i++
        }
    }
    return $CreatedPortGroups -as [string[]]
}
