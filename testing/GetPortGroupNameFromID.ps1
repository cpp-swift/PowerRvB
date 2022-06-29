$key = "dvportgroup-4179"

$name = Get-VDPortGroup | Where-Object {$_."Key" -eq $key} | Select-Object -ExpandProperty "Name"

Write-Output $name