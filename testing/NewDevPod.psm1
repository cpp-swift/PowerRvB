function New-DevPod {
    param(
        [Parameter(Mandatory=$true)]
        [String] $Name,
        [Parameter(Mandatory=$true)]
        [String] $Target,
        [Boolean] $CreateRouter,
        [String] $LanSubnet,
        [String] $WanPortGroup
    )
    $PortGroupList = Get-VDPortgroup -VDSwitch Main_DSW | Select -ExpandProperty name | sort
    $PortGroupList = $PortGroupList | 
        ForEach-Object {
            [int]$PortGroupList[$PortGroupList.indexOf($_)].Substring(0, $PortGroupList[$PortGroupList.indexOf($_)].indexOf('_'))
        }
    $PortGroupList = $PortGroupList.where{$_ -IN 1300..1399}
    for($i = 1300; $i -lt 1400; $i++) {
        if($PortGroupList.length -eq 0) {
            $DevPortGroup = $i
            break
        } elseif($PortGroupList.IndexOf($i) -eq -1) {
            $DevPortGroup = $i
            break
    }
}
    New-VDPortgroup -VDSwitch Main_DSW -Name $DevPortGroup'_DevPod' -VlanId $DevPortGroup
    New-VApp -Location $Target -Name $Name

}

function New-PodRouter {
    param (
        [String] $Target,
        [String] $LanSubnet,
        [String] $WanPortGroup,
        [int] $LanPortgroup
    )
}