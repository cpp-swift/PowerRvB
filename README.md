# PowerRvB Documentation

# PowerRvB

PowerRvB is a set of PowerShell commands that provision new environments on vSphere. Its included commands are:

- Invoke-PodClone
- New-DevPod
- New-PodPortGroups
- New-PodRouter
- Invoke-RvByeBye

# Getting Started

<aside>
💡 For best results in the SDC, the following should be done on scar.sdc.cpp or simba.sdc.cpp

</aside>

## Step 1: Dependencies

PowerRvB requires two PowerShell modules to be installed before you can start working. These are

- VMware.PowerCLI
- PowerRvB

```powershell
PS> Install-Module VMware.PowerCLI, PowerRvB
```

If you want to make Pod Users, the ActiveDirectory module will also be needed. You will also need to run the commands on a computer with domain management tools (scar.sdc.cpp or simba.sdc.cpp).

```powershell
PS> Install-Module ActiveDirectory
```

## Step 2: Connect to vSphere

Use your vSphere credentials to connect to elsa.sdc.cpp in PowerShell. If you are using PowerRvB on a VM joined to the sdc.cpp domain, you will not need to specify credentials.

```powershell
PS> Set-PowerCLIConfiguration -InvalidCertificateAction Ignore

PS> Connect-VIServer elsa.sdc.cpp -User <Username> -Password <Password>

# Note: Passwords with symbols may not work without being enclosed with ''
PS> Connect-VIServer elsa.sdc.cpp -User tswift -Password 'Thanus$Password'
```

<aside>
💡 The first line of this script block is required to connect to elsa.sdc.cpp, as it does not have a valid certificate.

</aside>

## Step 3: Create a Development Pod

Use **New-DevPod** to create a vApp for environment development.

```powershell
PS> New-DevPod -Name <vAppName> -Target <ResourcePoolName> -CreateRouter <$true|$false> -WanPortGroup <PortGroupName>

PS> New-DevPod -Name EvansDevPod3 -Target 02-07_Evan -CreateRouter $true -WanPortGroup 0010_DefaultNetwork
```

**New-DevPod** has a box selection menu.

```powershell
0 - Windows 10 Blank

1 - Windows Server 2022 Blank

2 - Ubuntu 20.04 Blank

Enter the boxes to be created in this Developer Pod (Ex: 0, 2, 1). Press enter to continue: 0, 0, 1
```

<aside>
💡 This input would create 2 Windows 10 boxes and 1 Server 2022 box in the development pod.

</aside>

## Step 4: Make a vApp Template

Once the environment in the Development Pod is complete, it is time to create a template for cloning. **If there is a Development Pod Router, delete the router before making a template of the vApp.** Individual Pod Routers must be created with the pods.

- Right click the vApp in vSphere, then create an OVF template in the Templates content library.

## Step 5: Clone the Pods

Using the template from Step 4 and **Invoke-PodClone**, you can create a specified number of Pods and supporting infrastructure. It will also tag all created resources for easy teardown using **Invoke-RvByeBye**

```powershell
PS> Invoke-PodClone -Template <Template> -Target <ResourcePool> -Pods <number> -Tag <Tag> -FirstPodNumber <number> -AssignPortGroups <$true|$false> -CreateUsers <$true|$false> -Role <vSphereRole> -CreateRouters <$true|$false>

PS> Invoke-PodClone -Template EvansTemplate -Target 02-07_Evan -Pods 20 -Tag 'RvB' -FirstPodNumber 1230 -AssignPortGroups $true -CreateUsers $true -Role 01_RvBDirector -CreateRouters $true
```

<aside>
💡 If CreateUsers is set as $true, a CSV will be created on the user’s desktop that lists usernames and passwords.

</aside>

## Step 6: Tearing Down Resources

**Invoke-RvByeBye** is used to remove all resources that were created by **Invoke-PodClone**. This deletes:

- vApps
- Port Groups
- Pod Users

```powershell
PS> Invoke-RvByeBye -Tag <Tag>
PS> Invoke-RvByeBye -Tag RvB
```

# Detailed Command Documentation

## Invoke-PodClone

### Syntax

```powershell
Invoke-PodClone
	-Template <String>
	-Target <String>
	-Pods <int>
	-Tag <String>
	-FirstPortGroup <int>
	[-CreateUsers <boolean>]
	[-Role <String>]
	[-CreateRouters <Boolean>]
```

### Description

The **Invoke-PodClone** cmdlet clones the given vSphere vApp a specified number of times. It also creates the required networking resources and users for each pod. 

If users are created, a CSV of usernames and passwords to be used on vSphere will be generated on the command runner’s desktop.

### Example 1

```powershell
PS> Invoke-PodClone -Template EvansTemplate -Target 02-07_Evan -Pods 20 -Tag 'RvB Tag' -FirstPodNumber 1230 -AssignPortGroups $true -CreateUsers $true -Role 01_RvBDirector -CreateRouters $true
```

This command clones the template, *EvansTemplate*, 20 times under the resource pool *02-07_Evan*. It creates 20 port groups starting at port group 1230. A domain user account is created for each pod and assigned the role *01_RvBDirector* on vSphere to their respective pod. It then creates a pod router for each pod. All created resources are tagged with *RvB Tag*.

### Example 2

```powershell
PS> Invoke-PodClone -Template WindowsWorkshop -Target 03-01_PodLabs -Pods 5 -Tag 'Windows Workshop' -FirstPodNumber 1230 -AssignPortGroups $false
```

This command clones the template, *WindowsWorkshop*, 5 times under the resource pool *03-01_PodLabs*. It creates 5 port groups starting at port group 1230. Pod Users and Routers will not be created. All created resources are tagged with *Windows Workshop*.

### Parameters

`-Template`

Specifies the vApp template to be cloned.

| Type: | String |
| --- | --- |
| Default value: | None |
| Accept pipeline input: | False |
| Mandatory: | True |

`-Target`

Specifies the resource pool the pods will be cloned to.

| Type: | String |
| --- | --- |
| Default value: | None |
| Accept pipeline input: | False |
| Mandatory: | True |

`-Pods`

Specifies the number of pods to be cloned.

| Type: | int |
| --- | --- |
| Default value: | None |
| Accept pipeline input: | False |
| Mandatory: | True |

`-Tag`

Specifies the tag applied to the vApps, Port Groups, and Users.

| Type: | String |
| --- | --- |
| Default value: | None |
| Accept pipeline input: | False |
| Mandatory: | True |

`-FirstPodNumber`

Specifies the first port group Invoke-PodClone will check for port groups.

| Type: | int |
| --- | --- |
| Default value: | None |
| Accept pipeline input: | False |
| Mandatory: | True |

`-AssignPortGroups`

Specifies if port groups will be assigned to the pods.

| Type: | Boolean |
| --- | --- |
| Default value: | None |
| Accept pipeline input: | False |
| Mandatory: | True |

`-CreateUsers`

Specify if users will also be created for their respective pods.

| Type: | Boolean |
| --- | --- |
| Default value: | $false |
| Accept pipeline input: | False |
| Mandatory: | False |

`-Role`

Specify the vSphere role new users will be given.

| Type: | String |
| --- | --- |
| Default value: | None |
| Accept pipeline input: | False |
| Mandatory: | Required if CreateUsers = True |

`-CreateRouters`

Specify if pod routers will be created.

| Type: | Boolean |
| --- | --- |
| Default value: | $false |
| Accept pipeline input: | False |
| Mandatory: | False |

## New-DevPod

### Syntax

```powershell
Invoke-PodClone
	-Name <String>
	-Target <String>
	[-CreateRouter <Boolean>]
	[-WanPortGroup <String>]
```

### Description

The **New-DevPod** cmdlet creates a development vApp with the desired virtual machines and functional networking. A prompt occurs after running the command that allows the user to choose what operating systems they want in the environment.

### Example 1

```powershell
PS> New-DevPod -Name EvansPod -Target 02-07_Evan
```

This command creates a development vApp named *EvansPod* under the resource pool *02-07_Evan*. It will not have a router created.

### Example 2

```powershell
PS> New-DevPod -Name EvansPod -Target 02-07_Evan -CreateRouter $true -WanPortGroup 0010_DefaultNetwork
```

This command creates a development vApp named *EvansPod* under the resource pool *02-07_Evan*. It will have a router created, with the WAN port group of 0010_DefaultNetwork.

### Parameters

`-Name`

Specifies the name of the vApp to be created.

| Type: | String |
| --- | --- |
| Default value: | None |
| Accept pipeline input: | False |
| Mandatory: | True |

`-Target`

Specifies the resource pool the vApp will be created in.

| Type: | String |
| --- | --- |
| Default value: | None |
| Accept pipeline input: | False |
| Mandatory: | True |

`-CreateRouter`

Specifies if pod router will be created.

| Type: | Boolean |
| --- | --- |
| Default value: | $false |
| Accept pipeline input: | False |
| Mandatory: | False |

`-WanPortGroup`

Specifies the WAN port used on the router.

| Type: | String |
| --- | --- |
| Default value: | None |
| Accept pipeline input: | False |
| Mandatory: | Required if CreateRouter = True |

## Invoke-RvByeBye

### Syntax

```powershell
Invoke-RvByeBye
	-Tag <String>
```

### Description

The **Invoke-RvByeBye** cmdlet removes all vApps, Port Groups, and Users with the tag specified.

### Example 1

```powershell
PS> Invoke-RvByeBye -Tag 'Spring RvB 2022'
```

This command removes all resources tagged with *Spring RvB 2022*. Typically, this would be all resources created by calling the Invoke-PodClone command with the Tag parameter set to *Spring RvB 2022*.

### Parameters

`-Tag`

Specifies the tag to be torn down.

| Type: | String |
| --- | --- |
| Default value: | None |
| Accept pipeline input: | False |
| Mandatory: | True |