# Variables
$name = 'Team13'
$target = ""

# Get resource group ID

# Get keys of 





$target = New-Object VMware.Vim.ManagedObjectReference
$target.Type = 'ResourcePool'
$target.Value = 'resgroup-4369' # ID of resource group
$spec = New-Object VMware.Vim.VAppCloneSpec
$spec.NetworkMapping = New-Object VMware.Vim.VAppCloneSpecNetworkMappingPair[] (1)
$spec.NetworkMapping[0] = New-Object VMware.Vim.VAppCloneSpecNetworkMappingPair
$spec.NetworkMapping[0].Destination = New-Object VMware.Vim.ManagedObjectReference
$spec.NetworkMapping[0].Destination.Type = 'DistributedVirtualPortgroup'
$spec.NetworkMapping[0].Destination.Value = 'dvportgroup-4179' # key of port group
$spec.NetworkMapping[0].Source = New-Object VMware.Vim.ManagedObjectReference
$spec.NetworkMapping[0].Source.Type = 'DistributedVirtualPortgroup'
$spec.NetworkMapping[0].Source.Value = 'dvportgroup-4024' # key of port group
$spec.VmFolder = New-Object VMware.Vim.ManagedObjectReference
$spec.VmFolder.Type = 'Folder'
$spec.VmFolder.Value = 'group-v4015' # key of the folder
$spec.Location = New-Object VMware.Vim.ManagedObjectReference
$spec.Location.Type = 'Datastore'
$spec.Location.Value = 'datastore-1021' # key of the datastore???
$spec.Provisioning = 'sameAsSource'
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
$_this = Get-View -Id 'VirtualApp-resgroup-v4016' # ID of Source vApp
$_this.CloneVApp_Task($name, $target, $spec)


