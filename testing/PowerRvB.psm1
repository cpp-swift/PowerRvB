function Invoke-PodClone {
    param(
        [Parameter(Mandatory)]
        [String] $Template,
        [Parameter(Mandatory)]
        [String] $Target,
        [Parameter(Mandatory)]
        [int] $Pods,
        [String] $Tag,
        [Boolean] $CreateUsers,
        [String] $Role,
        [Boolean] $CreateRouters,
        [int] $FirstPortGroup
    )

    if ($FirstPortGroup -ne $null) { $CreatedPortGroups = New-PodPortGroups -Portgroups $Pods -StartPort $FirstPortGroup -EndPort ($FirstPortGroup + $Pods + 20) } 
    else { $CreatedPortGroups = New-PodPortGroups -Portgroups $Pods -StartPort 1200 -EndPort 1299 }

    for($i = 0; $i -lt $Pods; $i++) {
            New-VApp -Name (-join ($CreatedPortGroups[$i + 1].name.Substring(0,5), 'Pod')) -Location (Get-ResourcePool -Name $Target) -ContentLibraryItem (Get-ContentLibraryItem -ContentLibrary Templates -Name $Template) -RunAsync
    }

    Write-Host -NoNewLine 'IMPORTANT: Do not continue until all vApps are created. Press any key to continue...' -ForegroundColor Red
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

    for($i = 0; $i -lt $Pods; $i++) {
        if ($CreateRouters -eq $true) {
            New-PodRouter -Target (-join ($CreatedPortGroups[$i + 1].name.Substring(0,5), 'Pod')) -WanPortGroup 0010_DefaultNetwork -LanPortGroup $CreatedPortGroups[$i + 1].name
        }
    }

    for($i = 0; $i -lt $Pods; $i++) {
        Get-VApp -Name (-join ($CreatedPortGroups[$i + 1].name.Substring(0,5), 'Pod')) | Get-VM | Where-Object -Property Name -NotLike '*PodRouter*' | 
            Get-NetworkAdapter -Name "Network adapter 1" | Set-NetworkAdapter -Portgroup $CreatedPortGroups[$i + 1] -Confirm:$false -RunAsync
    }
    if ($CreateUsers -eq $true) {
        foreach ($name in $CreatedPortGroups.Name) {   
            $names += $name.Substring(0, 8)
        }
        New-PodUsers -Pods $names -Role $Role
    }   

}

# Password generation function
function Get-RandomPassword {
    param (
        [Parameter(Mandatory)]
        [ValidateRange(4,[int]::MaxValue)]
        [int] $length,
        [int] $upper = 1,
        [int] $lower = 1,
        [int] $numeric = 1,
        [int] $special = 1
    )
    if($upper + $lower + $numeric + $special -gt $length) {
        throw "number of upper/lower/numeric/special char must be lower or equal to length"
    }
    $uCharSet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $lCharSet = "abcdefghijklmnopqrstuvwxyz"
    $nCharSet = "0123456789"
    $sCharSet = "/*-+,!?=()@;:._"
    $charSet = ""
    if($upper -gt 0) { $charSet += $uCharSet }
    if($lower -gt 0) { $charSet += $lCharSet }
    if($numeric -gt 0) { $charSet += $nCharSet }
    if($special -gt 0) { $charSet += $sCharSet }
    
    $charSet = $charSet.ToCharArray()
    $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    $bytes = New-Object byte[]($length)
    $rng.GetBytes($bytes)
 
    $result = New-Object char[]($length)
    for ($i = 0 ; $i -lt $length ; $i++) {
        $result[$i] = $charSet[$bytes[$i] % $charSet.Length]
    }
    $password = (-join $result)
    $valid = $true
    if($upper   -gt ($password.ToCharArray() | Where-Object {$_ -cin $uCharSet.ToCharArray() }).Count) { $valid = $false }
    if($lower   -gt ($password.ToCharArray() | Where-Object {$_ -cin $lCharSet.ToCharArray() }).Count) { $valid = $false }
    if($numeric -gt ($password.ToCharArray() | Where-Object {$_ -cin $nCharSet.ToCharArray() }).Count) { $valid = $false }
    if($special -gt ($password.ToCharArray() | Where-Object {$_ -cin $sCharSet.ToCharArray() }).Count) { $valid = $false }
 
    if(!$valid) {
         $password = Get-RandomPassword $length $upper $lower $numeric $special
    }
    return $password
}

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
            Get-VM -Name $Boxes[$i] | Get-NetworkAdapter -Name "Network adapter 1" | Set-NetworkAdapter -Portgroup $DevPortGroup[1] -Confirm:$false
        }
    }
}

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

function New-PodUsers {

    param(
        [Parameter(Mandatory=$true)]
        [String[]] $Pods,
        [Parameter(Mandatory=$true)]
        [String] $Role
    )

    # Creating the User Accounts
    Import-Module ActiveDirectory
    $users = @{}
    for($i = 0; $i -lt $Pods.Length; $i++) {
        $Password = Get-RandomPassword 12 1 1 1 1
        $Name = $Pods[$i] + '_User'
        $users.Add($Name, $Password)
        $Password = ConvertTo-SecureString -AsPlainText $Password -Force
        New-ADUser -Name $Name -ChangePasswordAtLogon $false -AccountPassword $Password -Enabled $true
        
        # Creating the Roles Assignments on vSphere
        New-VIPermission -Role (Get-VIRole -Name $Role) -Entity (Get-VApp -Name $Pods[$i]) -Principal ('SDC\' + $Name)
    }
    
    # Outputting the User CSV to Desktop
    $users.GetEnumerator() | Select-Object -Property Name,Value | Export-Csv -NoTypeInformation -Path $env:USERPROFILE\Desktop\Users.csv
}