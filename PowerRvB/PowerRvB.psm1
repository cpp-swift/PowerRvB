function Invoke-PodClone {
    param(
        [Parameter(Mandatory)]
        [String] $SourceResourcePool,
        [Parameter(Mandatory)]
        [String] $Target,
        [Parameter(Mandatory)]
        [int] $Pods,
        [Parameter(Mandatory)]
        [String] $Tag,
        [Parameter(Mandatory)]
        [Boolean] $AssignPortGroups,
        [Parameter(Mandatory)]
        [int] $FirstPodNumber,
        [Boolean] $CompetitionSetup=$True,
        [Boolean] $CreateUsers,
        [String] $Domain='sdc.cpp',
        [String] $Role,
        [Boolean] $CreateRouters,
        [String] $WanPortGroup='0010_DefaultNetwork'
    )

    try {
        Get-Tag -Name $Tag -ErrorAction Stop| Out-Null
    }
    catch {
        New-TagCategory -Name $Tag -Description $tag -EntityType VApp, DistributedPortGroup, VM | Out-Null
        New-Tag -Name $Tag -Category (Get-TagCategory -Name $Tag) | Out-Null
    }

    $CreatedPortGroups = New-PodPortGroups -Portgroups $Pods -StartPort $FirstPodNumber -EndPort ($FirstPodNumber + $Pods + 20) -Tag $Tag -AssignPortGroups $AssignPortGroups

    for ($i = 0; $i -lt $Pods; $i++) {
        Write-Host 'Creating' ( -join ($CreatedPortGroups[$i], '_Pod...'))
        New-VApp -Name ( -join ($CreatedPortGroups[$i], '_Pod')) -Location (Get-ResourcePool -Name $Target -ErrorAction Stop) -ErrorAction Stop | New-TagAssignment -Tag $Tag | Out-Null
    }

    $VMsToClone = Get-ResourcePool -Name $SourceResourcePool | Get-VM

    $VMsToClone | ForEach-Object {
        if (Get-Snapshot -VM $_ | Where-Object name -eq SnapshotForCloning) {
            $_ | Get-Snapshot -Name SnapshotForCloning | Remove-Snapshot -Confirm:$false
        }
        New-Snapshot -VM $_ -Name SnapshotForCloning
    }

    foreach ($VM in $VMsToClone) {
        Get-VApp -Tag $Tag | ForEach-Object { New-VM -VM $VM -Name ( -join (($_.Name.Split("P")[0]), $VM.Name)) -ResourcePool (Get-VApp -Name ($_.Name)).Name -LinkedClone -ReferenceSnapshot "SnapshotForCloning" -RunAsync }
    }

    $CloningCompletion = $false
    While (!$CloningCompletion) {
        $testNetAdapter = Get-VApp -Tag $Tag | Get-VM | Get-NetworkAdapter
        if ($testNetAdapter.Count -eq (($VMsToClone.Count) * $Pods)) {
            $CloningCompletion = $true
            Write-Progress -Activity "Cloning in Progress..." -Status "percent complete: 100" -PercentComplete 100
        } else {
            $CloningCompletion = $false
            $PercentComplete = [math]::Round(($testNetAdapter.Count / (($VMsToClone.Count) * $Pods)) * 100, 2)
            Write-Progress -Activity "Cloning in Progress..." -Status "percent complete: $PercentComplete" -PercentComplete $PercentComplete
            Start-Sleep 2
        }
    }

    if ($CreateRouters -eq $true) {
        Write-Host 'Creating the pod routers...'
        if ($CompetitionSetup -eq $True) {
            for ($i = 0; $i -lt $Pods; $i++) {
                Write-Host 'Creating' ( -join ($CreatedPortGroups[$i], '_Pod Router...'))
                New-PodRouter -Target ( -join ($CreatedPortGroups[$i], '_Pod')) -WanPortGroup $WanPortGroup -LanPortGroup ( -join ($CreatedPortGroups[$i], '_PodNetwork')) -PFSenseTemplate '1:1NAT_PodRouter' -ErrorAction Stop | Out-Null
            }
        } else {
            for ($i = 0; $i -lt $Pods; $i++) {
                Write-Host 'Creating' ( -join ($CreatedPortGroups[$i], '_Pod Router...'))
                New-PodRouter -Target ( -join ($CreatedPortGroups[$i], '_Pod')) -WanPortGroup $WanPortGroup -LanPortGroup ( -join ($CreatedPortGroups[$i], '_PodNetwork')) -PFSenseTemplate 'pfSense Blank' | Out-Null
            }
        }
    }

    if ($AssignPortGroups) {
        #Set Variables
        $CloningCompletion = $true
        $Routers = Get-VApp -Tag $Tag -ErrorAction Stop | Get-VM | Where-Object -Property Name -Like '*PodRouter*'
        $VMs = Get-VApp -Tag $Tag -ErrorAction Stop | Get-VM | Where-Object -Property Name -NotLike '*PodRouter*'
                    
        #Set VM Port Groups
        if ($VMs) {
            $VMs | 
                ForEach-Object { 
                    Get-NetworkAdapter -VM $_ -Name "Network adapter 1" -ErrorAction Stop | 
                        Set-NetworkAdapter -Portgroup (Get-VDPortGroup -name ( -join ($_.Name.Split("_")[0], '_PodNetwork'))) -Confirm:$false -RunAsync | Out-Null 
                }
        }
        #Set Router Port Groups
        $Routers | 
            ForEach-Object {
            Get-NetworkAdapter -VM $_ -Name "Network adapter 1" -ErrorAction Stop | 
                Set-NetworkAdapter -Portgroup (Get-VDPortgroup -Name $WanPortGroup) -Confirm:$false -RunAsync | Out-Null 
            Get-NetworkAdapter -VM $_ -Name "Network adapter 2" -ErrorAction Stop | 
                Set-NetworkAdapter -Portgroup (Get-VDPortGroup -name ( -join ($_.Name.Split("_")[0], '_PodNetwork'))) -Confirm:$false -RunAsync | Out-Null 
            }
    }
    
    
    
    $names = @()
    if ($CreateUsers -eq $true) {
        foreach ($name in $CreatedPortGroups) {   
            $names += ( -join ($name, '_Pod'))
        }
        Write-Host 'Creating the pod users...'
        New-PodUsers -Pods $names -Role $Role -Description $Tag -Domain $Domain | Out-Null
    }
    <#
        .SYNOPSIS
        Clones the given vSphere vApp a specified number of times.

        .PARAMETER Template
        Specifies the vApp template to be cloned.

        .PARAMETER Target
        Specifies the resource pool the pods will be cloned to.
        
        .PARAMETER Pods
        Specifies the number of pods to be cloned.

        .PARAMETER Tag
        Specifies the tag applied to the vApps, Port Groups, and Users.

        .PARAMETER FirstPortGroup
        Specifies the first port group Invoke-PodClone will check for port groups. 

        .PARAMETER CreateUsers
        Specify if users will also be created for their respective pods.
        
        .PARAMETER Role
        Specify the vSphere role new users will be given.

        .PARAMETER CreateRouters
        Specify if pod routers will be created.

        .INPUTS
        None. You cannot pipe objects to Invoke-PodClone.

        .OUTPUTS
        Invoke-PodClone does not return any output.

        .EXAMPLE
        PS> Invoke-PodClone -Template EvansTemplate -Target 02-07_Evan -Pods 20 -Tag 'RvB Tag' -FirstPortGroup 1230 -CreateUsers $true -Role 01_RvBDirector -CreateRouters $true

        .LINK
        PowerRvB's Github Repository: https://github.com/cpp-swift/PowerRvB
    #>
    
}

# Password generation function
function Get-RandomPassword {
    param (
        [Parameter(Mandatory)]
        [ValidateRange(4, [int]::MaxValue)]
        [int] $length,
        [int] $upper = 1,
        [int] $lower = 1,
        [int] $numeric = 1,
        [int] $special = 1
    )
    if ($upper + $lower + $numeric + $special -gt $length) {
        throw "number of upper/lower/numeric/special char must be lower or equal to length"
    }
    $uCharSet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $lCharSet = "abcdefghijklmnopqrstuvwxyz"
    $nCharSet = "0123456789"
    $sCharSet = "/*-+,!?=()@;:._"
    $charSet = ""
    if ($upper -gt 0) { $charSet += $uCharSet }
    if ($lower -gt 0) { $charSet += $lCharSet }
    if ($numeric -gt 0) { $charSet += $nCharSet }
    if ($special -gt 0) { $charSet += $sCharSet }
    
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
    if ($upper -gt ($password.ToCharArray() | Where-Object { $_ -cin $uCharSet.ToCharArray() }).Count) { $valid = $false }
    if ($lower -gt ($password.ToCharArray() | Where-Object { $_ -cin $lCharSet.ToCharArray() }).Count) { $valid = $false }
    if ($numeric -gt ($password.ToCharArray() | Where-Object { $_ -cin $nCharSet.ToCharArray() }).Count) { $valid = $false }
    if ($special -gt ($password.ToCharArray() | Where-Object { $_ -cin $sCharSet.ToCharArray() }).Count) { $valid = $false }
 
    if (!$valid) {
        $password = Get-RandomPassword $length $upper $lower $numeric $special
    }
    return $password
}

#Create a new Pod for Development
function New-DevPod {

    param(
        [Parameter(Mandatory = $true)]
        [String] $Name,
        [Parameter(Mandatory = $true)]
        [String] $Target,
        [Boolean] $CreateRouter,
        [String] $WanPortGroup
    )

    # Creates the Dev Port Group, vApp, and Router
    $DevPortGroup = New-PodPortGroups -Portgroups 1 -StartPort 1300 -EndPort 1350 -AssignPortGroups $true
    New-VApp -Location $Target -Name $Name | Out-Null
    if ($CreateRouter -eq $true) {
        New-PodRouter -Target $Name -WanPortGroup $WanPortGroup -LanPortGroup ( -join ($DevPortGroup[0], '_PodNetwork')) -PFSenseTemplate "pfSense Blank" -ErrorAction Stop| Out-Null
    }

    $Templates = Get-Template | Sort-Object

    foreach ($template in $Templates) {
        Write-Host $Templates.IndexOf($template)'-' "$template" `n
    }

    $boxes = (Read-Host "Enter the boxes to be created in this Developer Pod (Ex: 0, 2, 1). Press enter to continue").split(',')
    $boxes = $boxes | ForEach-Object { $_ -Replace '\s', '' }

    if ($Boxes) {
        for ($i = 0; $i -ile $Boxes.Count; $i++) {
            New-VM -Name $Templates.Get($Boxes[$i].ToString()).Name `
                -ResourcePool (Get-VApp -Name ($Name)).Name `
                -Datastore (Get-DataStore -Name Ursula) `
                -Template $Templates.get($Boxes[$i].ToString()) -RunAsync -ErrorAction Stop | Out-Null
        }
        
        Write-Host 'IMPORTANT: Do not continue until all VMs are created. Press any key to continue...' -ForegroundColor Red
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
    
        for ($i = 0; $i -lt $Boxes.Count; $i++) {
            Get-ResourcePool (Get-VApp -Name ($Name)).Name -ErrorAction Stop | Get-VM | Where-Object -Property Name -NotLike '*PodRouter*' | Get-NetworkAdapter -Name "Network adapter 1" | Set-NetworkAdapter -Portgroup (Get-VDPortGroup -Name ( -join ($DevPortGroup[0], '_PodNetwork'))) -Confirm:$false -RunAsync | Out-Null
        }
    }

    
    <#
        .SYNOPSIS
        Creates a Development vApp with the desired virtual machines and functional networking.

        .PARAMETER Name
        Specifies the name of the vApp to be created.

        .PARAMETER Target
        Specifies the resource pool the vApp will be created in.
        
        .PARAMETER CreateRouter
        Specifies if pod router will be created.

        .PARAMETER WanPortGroup
        Specifies the WAN port used on the router.

        .INPUTS
        None. You cannot pipe objects to New-DevPod.

        .OUTPUTS
        New-DevPod does not return any output.

        .EXAMPLE
        PS> New-DevPod -Name EvansDevPod3 -Target 02-07_Evan -CreateRouter $true -WanPortGroup 0010_DefaultNetwork

        .LINK
        PowerRvB's Github Repository: https://github.com/cpp-swift/PowerRvB
    #>
}

#Create Port Groups
function New-PodPortGroups {

    param(
        [ValidateRange(1, 100)]
        [Parameter(Mandatory = $true)]
        [int] $Portgroups,
        [ValidateRange(1000, 2000)]
        [Parameter(Mandatory = $true)]
        [int] $StartPort,
        [ValidateRange(1000, 2000)]
        [Parameter(Mandatory = $true)]
        [int] $EndPort,
        [String] $Tag,
        [Boolean] $AssignPortGroups

    )

    $ErrorActionPreference = "Stop"

    # Gets the list of existing port groups in the range
    $PortGroupList = Get-VDPortgroup -VDSwitch Main_DSW | Select-Object -ExpandProperty name | Sort-Object
    $PortGroupList = $PortGroupList | 
    ForEach-Object {
        [int]$PortGroupList[$PortGroupList.indexOf($_)].Substring(0, $PortGroupList[$PortGroupList.indexOf($_)].indexOf('_'))
    }
    $PortGroupList = $PortGroupList.where{ $_ -IN $StartPort..$EndPort }
    # Check if Port Groups can be created
    if ($EndPort - $StartPort - $PortGroupList.Count + 1 -lt $Portgroups) {
        $temp = $EndPort - $StartPort - $PortGroupList.Count + 1
        Write-Error -Message "There are not enough port groups available in this range. Only $temp can be created."
    }

    # Creates the port groups
    $j = $StartPort
    $i = 0
    While ($i -le $Portgroups - 1) {
        if ($PortGroupList.IndexOf($j) -ne -1) { $j++; continue }
        if ($j -gt $EndPort) { Write-Error -Message "There are no more available port groups in the specified range." }
        else {
            if ($AssignPortGroups) {
                Write-Host "Creating Port Group $j..."
                New-VDPortgroup -VDSwitch Main_DSW -Name ( -join ($j, '_PodNetwork')) -VlanId $j | Out-Null
                if ($Tag) {
                    Get-VDPortGroup -Name ( -join ($j, '_PodNetwork')) | New-TagAssignment -Tag (Get-Tag -Name $Tag) | Out-Null
                }
            }
            $j
            $j++
            $i++
        }
    }
    return $CreatedPortGroups

    <#
        .SYNOPSIS
        Creates a specified number of port groups within the given range.

        .DESCRIPTION
        Finds the first available port group and every subsequent available port group in the range until a specified amount of port groups are created.
        Errors out if the range does not have enough available port groups.

        .PARAMETER PortGroups
        Specifies the number of port groups to be created.

        .PARAMETER StartPort
        Specifies the first usable port.
        
        .PARAMETER EndPort
        Specifies the last usable port. 

        .PARAMETER Tag
        Specifies the Tag applied to the port groups.

        .INPUTS
        None. You cannot pipe objects to New-PodPortGroups.

        .OUTPUTS
        Int32 Array. New-PodPortGroups returns an array of the VLAN IDs used by the created port groups.

        .EXAMPLE
        PS> New-PodPortGroups -PortGroups 10 -StartPort 1200 -EndPort 1300

        .LINK
        PowerRvB's Github Repository: https://github.com/cpp-swift/PowerRvB
    #>
}

# Creates a pfSense Router for the vApp 
function New-PodRouter {

    param (
        [Parameter(Mandatory = $true)]
        [String] $Target,
        [Parameter(Mandatory = $true)]
        [String] $WanPortGroup,
        [Parameter(Mandatory = $true)]
        [String] $LanPortGroup,
        [Parameter(Mandatory = $true)]
        [String] $PFSenseTemplate

    )

    # Creating the Router
    $name = ( -join ($LanPortGroup.Substring(0, 4), '_PodRouter'))
    New-VM -Name $name `
        -ResourcePool (Get-Vapp -Name $Target).Name `
        -Datastore (Get-DataStore -Name Ursula) `
        -Template (Get-Template -Name $PFSenseTemplate) | Out-Null

    Get-VM -Name $name | Start-VM
    
    $SSHTest = $True
    if ($PFSenseTemplate -eq '1:1NAT_PodRouter') {
        Start-Sleep 30 
        while ($SSHTest) {
                $ThirdOctet = $LanPortGroup.Substring(2, 2)
                if ($ThirdOctet.StartsWith('0')) {
                    $ThirdOctet = $ThirdOctet.Substring(1,1)
                }
                $commands = "sed 's/172.16.254/172.16.$ThirdOctet/g' /cf/conf/config.xml > tempconf.xml; cp tempconf.xml /cf/conf/config.xml; rm /tmp/config.cache; /etc/rc.reload_all start"
                ssh "admin@172.16.254.1" $commands -ErrorAction continue
                $SSHTest = $false
            }
        }
    

    # Assigning port groups to the interfaces
   
    <#
        .SYNOPSIS
        Creates a router in a specified vApp.

        .DESCRIPTION
        Creates a router with a specified WAN port group and a specified LAN port group. 

        .PARAMETER Target
        Specifies the vApp the Router will be created in.

        .PARAMETER WanPortGroup
        Specifies the WAN port group.
        
        .PARAMETER LanPortGroup
        Specifies the LAN port group.

        .INPUTS
        None. You cannot pipe objects to New-PodRouter.

        .OUTPUTS
        New-PodRouter does not return any output.

        .EXAMPLE
        PS> New-PodRouter -Target EvansvApp -WanPortgroup 0010_DefaultNetwork -LanPortgroup 1200_PodNetwork

        .LINK
        PowerRvB's Github Repository: https://github.com/cpp-swift/PowerRvB
    #>
} 

function New-PodUsers {

    param(
        [Parameter(Mandatory = $true)]
        [String[]] $Pods,
        [Parameter(Mandatory = $true)]
        [String] $Role,
        [Parameter(Mandatory = $true)]
        [String] $Description,
        [Parameter(Mandatory = $true)]
        [String] $Domain
    )

    # Creating the User Accounts
    Import-Module ActiveDirectory
    $file = ( -join ("$env:USERPROFILE\Desktop\", $Description , "Users.csv"))
    ForEach ($Pod in $Pods) {
        $Password = Get-RandomPassword 12 1 1 1 1
        $Name = ( -join ($Pod, 'User'))
        $SecurePassword = ConvertTo-SecureString -AsPlainText $Password -Force
        Write-Host 'Creating user' $Name
        New-ADUser -Name $Name -ChangePasswordAtLogon $false -AccountPassword $SecurePassword -Enabled $true -Description $Description -UserPrincipalName (-join ($Name, '@', $Domain))| Out-Null
        Add-ADGroupMember -Identity 'RvB Competitors' -Members $Name

        # Creating the Roles Assignments on vSphere
        New-VIPermission -Role (Get-VIRole -Name $Role -ErrorAction Stop) -Entity (Get-VApp -Name $Pod) -Principal ($Domain.Split(".")[0] + '\' + $Name) | Out-Null
        
        #Append User to CSV
        $out = "$Name,$Password"
        $out | Out-File $file -Append -Force
    }

    <#
        .SYNOPSIS
        Creates AD Users that correspond to specified pods and assigns them a specified vSphere role.

        .PARAMETER Pods
        Specifies the pods to create users for.

        .PARAMETER Role
        Specifies the vSphere role to be applied.
        
        .PARAMETER Description
        Specifies a description that is given to the users in AD.

        .INPUTS
        None. You cannot pipe objects to New-PodUsers.

        .OUTPUTS
        CSV File. On the cmdlet user's desktop, a CSV of usernames and passwords is generated.

        .EXAMPLE
        PS> New-PodUsers -Pods '1200_Pod','1201_Pod' -Role 01_RvBCompetitors -Description 'RvB Tag'

        .LINK
        PowerRvB's Github Repository: https://github.com/cpp-swift/PowerRvB
    #>
}

function Invoke-RvByeBye {
    
    param(
        [Parameter(Mandatory)]
        [String] $Tag
    )
    Get-VApp -Tag $Tag | Get-VM | Stop-VM -Confirm:$false | Out-Null
    Get-VApp -Tag $Tag | Get-VM | Remove-VM -DeletePermanently | Out-Null
    Get-Vapp -Tag $Tag | Remove-VApp -DeletePermanently | Out-Null
    Get-VDPortgroup -Tag $Tag -ErrorAction Stop | Remove-VDPortGroup -ErrorAction Stop | Out-Null
    Get-ADUser -Filter { Description -eq $Tag } | Remove-ADUser -ErrorAction Stop | Out-Null
    Get-TagCategory -Name $Tag -ErrorAction Stop | Remove-TagCategory -ErrorAction Stop | Out-Null

    <#
        .SYNOPSIS
        Removes all resources with a specified tag.

        .PARAMETER Tag
        Specifies the tag to be used.

        .INPUTS
        None. You cannot pipe objects to Invoke-RvByeBye.

        .OUTPUTS
        Invoke-RvByeBye does not return any output.
        
        .EXAMPLE
        PS> Invoke-RvByeBye -Tag 'RvB Tag'

        .LINK
        PowerRvB's Github Repository: https://github.com/cpp-swift/PowerRvB
    #>
}

function Invoke-ConfigureVMs {
    param (
        [cmdletbinding(SupportsShouldProcess)]
        [Parameter(Mandatory,ValueFromPipeline=$true)]
        [Object] $VM,
        [string] $NewTag=$null,
        [string] $Name,
        [int] $NewPortGroup=$null,
        [int] $NumCpu=$null,
        [int] $MemoryGB=$null,
        [Boolean] $CpuHotAddEnabled,
        [Boolean] $CpuHotRemoveEnabled,
        [Boolean] $MemoryHotAddEnabled

        
    )

    begin {

        if($NewPortGroup) {
            try {
                Get-VDPortgroup -Name ( -join ($NewPortGroup, '_PodNetwork')) -ErrorAction Stop
            }
            catch {
                New-VDPortgroup -VDSwitch Main_DSW -Name ( -join ($NewPortGroup, '_PodNetwork')) -VlanId $NewPortGroup | Out-Null
                Get-VDPortGroup -Name ( -join ($NewPortGroup, '_PodNetwork')) | New-TagAssignment -Tag (Get-Tag -Name $NewTag)
            }
        }
    }

    process {
        #$ErrorActionPreference = 'SilentlyContinue'
        if ($NewTag) { $VM | New-TagAssignment -Tag (Get-Tag -Name $NewTag)}
        if ($NewPortGroup) { $VM | Get-NetworkAdapter -Name "Network adapter 1" | Set-NetworkAdapter -Portgroup (Get-VDPortgroup -Name ( -join ($NewPortGroup, "_PodNetwork"))) -Confirm:$false -RunAsync | Out-Null }
        if ($NumCpu) { $VM | Set-VM -NumCpu $NumCpu -Confirm:$false -RunAsync }
        if ($MemoryGB) { $VM | Set-VM -MemoryGB $MemoryGB -Confirm:$false -RunAsync }
        if ($Name) { $VM | Set-VM -Name $Name -RunAsync -Confirm:$false }
        if ($MemoryHotAddEnabled) {$VM | Stop-VM -Confirm:$false | Set-VM -MemoryHotAddEnabled $MemoryHotAddEnabled -Confirm:$false -RunAsync }
        if ($CpuHotAddEnabled) {$VM | Stop-VM -Confirm:$false | Set-VM -CpuHotAddEnabled $CpuHotAddEnabled -Confirm:$false -RunAsync }
        if ($CpuHotRemoveEnabled) { $VM | Stop-VM -Confirm:$false | Set-VM -CpuHotRemoveEnabled $CpuHotRemoveEnabled -Confirm:$false -RunAsync }
    }
}