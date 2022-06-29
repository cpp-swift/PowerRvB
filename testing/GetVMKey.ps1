$vm_name = Read-Host "Please enter in the name of the VM"

$vm_key = Get-VM -Name $vm_name | Select-Object -ExpandProperty "Id"
Write-Output $vm_key