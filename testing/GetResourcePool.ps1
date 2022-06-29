$rp_name = "00_SDCCritical"

$rp_id = Get-ResourcePool -Name $rp_name | Select-Object -ExpandProperty "Id"

$rp_id.Substring(13)