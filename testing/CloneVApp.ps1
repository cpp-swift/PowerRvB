$myVApp = Get-CIVapp -Name "02-05_TestvApp"
New-CIVApp -Name "02-05_TestVAppClone" -Description "my cloned vapp" -VApp