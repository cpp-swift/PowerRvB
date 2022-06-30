<#
Creates users for pods
Author: Evan Deters
#>

function New-PodUsers {

    param(
        [Parameter(Mandatory=$true)]
        [String[]] $Pods,
        [Parameter(Mandatory=$true)]
        [String] $Role
    )

    $users = @{}
    Import-Module ActiveDirectory
    for($i = 0; $i -lt $Pods.Length; $i++) {
        $Password = Get-RandomPassword 12
        $Name = $Pods[$i] + '_User'
        $users.Add($Name, $Password)
        $Password = ConvertTo-SecureString -AsPlainText $Password -Force
        New-ADUser -Name $Name -ChangePasswordAtLogon $false -AccountPassword $Password
        
        New-VIPermission -Role (Get-VIRole -Name $Role) -Entity (Get-VApp -Name $Pods[$i]) -Principal ('SDC\' + $Name)
    }
    
    $users
}

function Get-RandomPassword {
    param (
        [Parameter(Mandatory)]
        [int] $length
    )
    $charSet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789*@$^%_!#?'.ToCharArray()
    $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    $bytes = New-Object byte[]($length)
 
    $rng.GetBytes($bytes)
 
    $result = New-Object char[]($length)
 
    for ($i = 0 ; $i -lt $length ; $i++) {
        $result[$i] = $charSet[$bytes[$i]%$charSet.Length]
    }
 
    return (-join $result)
}