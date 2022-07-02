function Invoke-PodClone {
    param(
        [Parameter(Mandatory)]
        [String] $Template,
        [Parameter(Mandatory)]
        [String] $Target,
        [Parameter(Mandatory)]
        [int] $Pods,
        [Parameter(Mandatory)]
        [String] $Tag,
        [Parameter(Mandatory)]
        [int] $FirstPortGroup,
        [Boolean] $CreateUsers,
        [String] $Role,
        [Boolean] $CreateRouters
        
    )

    New-TagCategory -Name $Tag -Description $tag -EntityType VApp,DistributedPortGroup,VM
    $vappCategory = Get-TagCategory -Name $Tag
    New-Tag -Name $Tag -Category $vappCategory

    $CreatedPortGroups = New-PodPortGroups -Portgroups $Pods -StartPort $FirstPortGroup -EndPort ($FirstPortGroup + $Pods + 20) -Tag $Tag
    
    for($i = 0; $i -lt $Pods; $i++) {
        New-VApp -Name (-join ($CreatedPortGroups[$i], '_Pod')) -Location (Get-ResourcePool -Name $Target) -ContentLibraryItem (Get-ContentLibraryItem -ContentLibrary Templates -Name $Template) -RunAsync
    }

    Write-Host -NoNewLine 'IMPORTANT: Do not continue until all vApps are created. Press any key to continue...' -ForegroundColor Red
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

    for($i = 0; $i -lt $Pods; $i++) {
        if ($CreateRouters -eq $true) {
            New-PodRouter -Target (-join ($CreatedPortGroups[$i], '_Pod')) -WanPortGroup 0010_DefaultNetwork -LanPortGroup (-join ($CreatedPortGroups[$i], '_PodNetwork'))
        }
    }

    for($i = 0; $i -lt $Pods; $i++) {
        Get-VApp -Name (-join ($CreatedPortGroups[$i], '_Pod')) | New-TagAssignment -Tag (Get-Tag -Name $Tag)
        Get-VApp -Name (-join ($CreatedPortGroups[$i], '_Pod')) | Get-VM | Where-Object -Property Name -NotLike '*PodRouter*' | 
            Get-NetworkAdapter -Name "Network adapter 1" | Set-NetworkAdapter -Portgroup (Get-VDPortGroup -name (-join ($CreatedPortGroups[$i], '_PodNetwork'))) -Confirm:$false -RunAsync
    }
    
    $names = @()
    if ($CreateUsers -eq $true) {
        foreach ($name in $CreatedPortGroups.Name) {   
            $names += $name.Substring(0, 8)
        }
        New-PodUsers -Pods $names -Role $Role -Description $Tag
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
        [String] $WanPortGroup
    )

    # Creates the Dev Port Group, vApp, and Router
    $DevPortGroup = New-PodPortGroups -Portgroups 1 -StartPort 1300 -EndPort 1350
    New-VApp -Location $Target -Name $Name
    if($CreateRouter -eq $true) {
        New-PodRouter -Target $Name -WanPortGroup $WanPortGroup -LanPortGroup (-join ($DevPortGroup[0], '_PodNetwork'))
    }

    $Templates = Get-Template | sort

    foreach ($template in $Templates) {
        Write-Host $Templates.IndexOf($template)'-' "$template" `n
    }

    $boxes = (Read-Host "Enter the boxes to be created in this Developer Pod (Ex: 0, 2, 1). Press enter to continue").split(',')
    $boxes = $boxes | %{$_ -Replace '\s',''}

    if($Boxes) {
        for ($i = 0; $i -lt $Boxes.Count; $i++) {
            New-VM -Name $Templates.Get($Boxes[$i]).Name `
             -ResourcePool (Get-VApp -Name $Name) `
             -Datastore (Get-DataStore -Name Ursula) `
             -Template $Templates.get($Boxes[$i])
            Get-VM -Name $Templates.Get($Boxes[$i]).Name | Get-NetworkAdapter -Name "Network adapter 1" | Set-NetworkAdapter -Portgroup (Get-VDPortGroup -Name (-join ($DevPortGroup[0], '_PodNetwork'))) -Confirm:$false -RunAsync
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
        [int] $EndPort,
        [String] $Tag

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
    While ($i -le $Portgroups - 1) {
        if($PortGroupList.IndexOf($j) -ne -1) { $j++; continue }
        if($j -gt $EndPort) { Write-Error -Message "There are no more available port groups in the specified range."}
        else {
            New-VDPortgroup -VDSwitch Main_DSW -Name (-join ($j, '_PodNetwork')) -VlanId $j | Out-Null
            if($Tag) {
                Get-VDPortGroup -Name (-join ($j, '_PodNetwork')) | New-TagAssignment -Tag (Get-Tag -Name $Tag) | Out-Null
            }
            $j
            $j++
            $i++
        }
    }
    return $CreatedPortGroups
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
    New-VM -Name (-join ($LanPortGroup.Substring(0,4), '_PodRouter')) `
     -ResourcePool (Get-VApp -Name $Target) `
     -Datastore (Get-DataStore -Name Ursula) `
     -Template (Get-Template -Name "pfSense Blank")

    # Assigning port groups to the interfaces
    Get-VM -Name (-join ($LanPortGroup.Substring(0,4), '_PodRouter')) | Get-NetworkAdapter -Name "Network adapter 1" | Set-NetworkAdapter -Portgroup (Get-VDPortgroup -Name $WanPortGroup) -Confirm:$false -RunAsync
    Get-VM -Name (-join ($LanPortGroup.Substring(0,4), '_PodRouter')) | Get-NetworkAdapter -Name "Network adapter 2" | Set-NetworkAdapter -Portgroup (Get-VDPortgroup -Name $LanPortGroup) -Confirm:$false -RunAsync
} 

function New-PodUsers {

    param(
        [Parameter(Mandatory=$true)]
        [String[]] $Pods,
        [Parameter(Mandatory=$true)]
        [String] $Role,
        [Parameter(Mandatory=$true)]
        [String] $Description
    )

    # Creating the User Accounts
    Import-Module ActiveDirectory
    $users = @{}
    for($i = 0; $i -lt $Pods.Length; $i++) {
        $Password = Get-RandomPassword 12 1 1 1 1
        $Name = $Pods[$i] + '_User'
        $users.Add($Name, $Password)
        $Password = ConvertTo-SecureString -AsPlainText $Password -Force
        New-ADUser -Name $Name -ChangePasswordAtLogon $false -AccountPassword $Password -Enabled $true -Description $Description
        
        # Creating the Roles Assignments on vSphere
        New-VIPermission -Role (Get-VIRole -Name $Role) -Entity (Get-VApp -Name $Pods[$i]) -Principal ('SDC\' + $Name)
    }
    
    # Outputting the User CSV to Desktop
    $users.GetEnumerator() | Select-Object -Property Name,Value | Export-Csv -NoTypeInformation -Path $env:USERPROFILE\Desktop\Users.csv
}

function Invoke-RvByeBye {
    
    param(
        [Parameter(Mandatory)]
        [String] $Tag
    )

    Get-VApp -Tag $Tag | Remove-VApp -DeletePermanently -Confirm:$false
    Get-VDPortgroup -Tag $Tag | Remove-VDPortGroup
    Get-ADUser -Filter {Description -eq $Tag} | Remove-ADUser
    Get-Tag -Name $Tag | Remove-Tag
    Get-TagCategory -Name $Tag | Remove-TagCategory
}

