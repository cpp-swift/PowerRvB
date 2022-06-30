# Variables
$Name = "02-05_TestVAppClone" # Name of new vApp

$ResourcePool = "02-05_TaylorsKingdom" # Target resource pool to clone the vApp into
$VApp = "02-05_TestvApp" # vApp to clone
$PortGroup = "0010_DefaultNetwork" # Port Group to clone
$Folder = "02_UserLabs"

# Get resource group ID
$ResourcePoolID = Get-ResourcePool -Name $ResourcePool | Select-Object -ExpandProperty "Id"
$ResourcePoolID = $ResourcePoolID.Substring(13)

# Get destination port group key
$PortGroupKey = Get-VDPortGroup -Name $PortGroup | Select-Object -ExpandProperty "Key"

# Get folder key
$FolderKeyFull = Get-Folder | Where-Object {$_."Name" -eq $Folder} | Select-Object -ExpandProperty "Id"
$FolderKey = $FolderKeyFull.Substring(7)

# Get ID of Source vApp
$VAppID = Get-Vapp | Where-Object {$_."Name" -eq $VApp} | Select-Object -ExpandProperty "Id"


$target = New-Object VMware.Vim.ManagedObjectReference
$target.Type = 'ResourcePool'
$target.Value = $ResourcePoolID # ID of resource group


# Create a new object VMware.Vim.VAppCloneSpec
$spec = New-Object VMware.Vim.VAppCloneSpec

# Specify network mappings
$spec.NetworkMapping = New-Object VMware.Vim.VAppCloneSpecNetworkMappingPair[] (1)
$spec.NetworkMapping[0] = New-Object VMware.Vim.VAppCloneSpecNetworkMappingPair
$spec.NetworkMapping[0].Destination = New-Object VMware.Vim.ManagedObjectReference
$spec.NetworkMapping[0].Destination.Type = 'DistributedVirtualPortgroup'
$spec.NetworkMapping[0].Destination.Value = $PortGroupKey # key of port group
$spec.NetworkMapping[0].Source = New-Object VMware.Vim.ManagedObjectReference
$spec.NetworkMapping[0].Source.Type = 'DistributedVirtualPortgroup'
$spec.NetworkMapping[0].Source.Value = $PortGroupKey # key of port group

# Specify folder
$spec.VmFolder = New-Object VMware.Vim.ManagedObjectReference
$spec.VmFolder.Type = 'Folder'
$spec.VmFolder.Value = $FolderKey # key of the folder

# Specify datastore
$spec.Location = New-Object VMware.Vim.ManagedObjectReference
$spec.Location.Type = 'Datastore'
$spec.Location.Value = 'datastore-1021' # key of the datastore - will always be the same

# Select thin-provision
$spec.Provisioning = 'thin'

# resource specifications
$spec.ResourceSpec = New-Object VMware.Vim.ResourceConfigSpec
$spec.ResourceSpec.MemoryAllocation = New-Object VMware.Vim.ResourceAllocationInfo
$spec.ResourceSpec.MemoryAllocation.Shares = New-Object VMware.Vim.SharesInfo
$spec.ResourceSpec.MemoryAllocation.Shares.Shares = 163840
$spec.ResourceSpec.MemoryAllocation.Shares.Level = 'normal'
$spec.ResourceSpec.MemoryAllocation.Limit = -1
$spec.ResourceSpec.MemoryAllocation.Reservation = 0
$spec.ResourceSpec.MemoryAllocation.ExpandableReservation = $true
$spec.ResourceSpec.ScaleDescendantsShares = 'disabled'
$spec.ResourceSpec.CpuAllocation = New-Object VMware.Vim.ResourceAllocationInfo
$spec.ResourceSpec.CpuAllocation.Shares = New-Object VMware.Vim.SharesInfo
$spec.ResourceSpec.CpuAllocation.Shares.Shares = 4000
$spec.ResourceSpec.CpuAllocation.Shares.Level = 'normal'
$spec.ResourceSpec.CpuAllocation.Limit = -1
$spec.ResourceSpec.CpuAllocation.Reservation = 0
$spec.ResourceSpec.CpuAllocation.ExpandableReservation = $true

# clone vapp
$_this = Get-View -Id $VAppID # ID of Source vApp
$_this.CloneVApp_Task($Name, $target, $spec)

# rename VMs in vapp
$VAppRename = Get-VApp -Name "02-05_TestvAppClone" | Get-VM
$VAppRename | ForEach-Object {
    $VAppRename | Set-VM -Name "Yes"
}