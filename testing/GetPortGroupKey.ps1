$pg_name = "0010_DefaultNetwork"

$pg_key = Get-VDPortGroup -Name $pg_name | Select-Object -ExpandProperty "Key"
Write-Output $pg_key