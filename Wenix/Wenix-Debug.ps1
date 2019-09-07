Clear-Host
Import-Module -Force -Verbose 'd:\alt-air\dev\github\Wenix\Wenix'
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

$bytes = [System.Text.Encoding]::Unicode.GetBytes( (Get-Command Show-Menu).Definition )
$encodedCommand = [Convert]::ToBase64String($bytes)

$AutoRun = (Get-Volume -FileSystemLabel 'OS').DriveLetter + ':\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\Add-Junctions.cmd'

'chcp 1251 && echo off' | Out-File -Encoding ascii -FilePath $AutoRun
'powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -encodedCommand {0}' -f $encodedCommand | Out-File -Encoding ascii -FilePath $AutoRun -Append
'timeout /t 13' | Out-File -Encoding ascii -FilePath $AutoRun -Append
'erase /f /q "%~dpnx0"' | Out-File -Encoding ascii -FilePath $AutoRun -Append
