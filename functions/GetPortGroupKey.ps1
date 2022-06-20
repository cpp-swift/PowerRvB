$pg_name = Read-Host "Please enter in the name of the port group"

$pg_key = Get-VirtualPortgroup -Name $pg_name | Select-Object -ExpandProperty "Key"
Write-Output $pg_key