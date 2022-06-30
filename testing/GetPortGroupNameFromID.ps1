$key = Read-Host "Please enter in the key of the Port Group"

$name = Get-VDPortGroup | Where-Object {$_."Key" -eq $key} | Select-Object -ExpandProperty "Name"

Write-Output $name