Clear-Host
Import-Module -Force -Verbose 
Get-Module -Name Wenix


# $NetConfig = Find-NetConfig

# $PEloc = Test-WimNet -md5 -ver 'PE' -name 'boot'    
# $OSloc = Test-WimNet -md5 -ver '10' -name 'install' 

# $shares = @()
# if ($null -ne $NetConfig) { $shares += $NetConfig | Read-NetConfig } # else { $shares = @() }

# # $ok = @{} ; $ver = '10' ; $name = 'install'
# if ($shares.Count -gt 0)
# {
#     # PE
#     $ver = 'PE' ; $name = 'boot'
#     $PEnet = Test-WimNet -SharesList $shares -ver $ver -name $name -md5
    
#     # OS
#     $ver = '10' ; $name = 'install'
#     $OSnet = Test-WimNet -SharesList $shares -ver $ver -name $name -md5 #:$false
# }

# $PEloc, $OSloc, $PEnet, $OSnet | ft *


# Use-Wenix -STOP

$command = (Get-Command Add-Junctions).Definition
$bytes = [System.Text.Encoding]::Unicode.GetBytes($command)
$encodedCommand = [Convert]::ToBase64String($bytes)

$AutoRun = (Get-Volume -FileSystemLabel 'OS').DriveLetter + ':\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\Add-Junctions.cmd'

'chcp 65001 && echo off' | Out-File -Encoding unicode -FilePath $AutoRun
'powershell.exe -encodedCommand {0}' -f $encodedCommand | Out-File -Encoding unicode -FilePath $AutoRun -Append