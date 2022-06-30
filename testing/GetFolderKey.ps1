$FolderName = Read-Host "Please input the name of the folder"

$FolderKey = Get-Folder | Where-Object {$_."Name" -eq $FolderName} | Select-Object -ExpandProperty "Id"

$FolderKey.Substring(7)