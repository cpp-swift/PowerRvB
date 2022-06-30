$pg_name = Read-Host "Please enter in the name of the Port Group"

$pg_key = Get-VDPortGroup -Name $pg_name | Select-Object -ExpandProperty "Key"
Write-Output $pg_key