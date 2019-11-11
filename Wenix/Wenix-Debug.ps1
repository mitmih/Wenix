Clear-Host
Import-Module -Force -Verbose Wenix
Get-Module -Name Wenix


Copy-WithCheck -from 'E:\.IT\PE' -to 'D:\.IT\PE'


# $NetConfig = Find-NetConfig

# $res = $NetConfig | Read-NetConfig

# $res


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



# $txt = Get-Content <# -Delimiter "`n" #> -Encoding UTF8 -Raw -Path ((Get-Module Wenix).NestedModules | Where-Object {$_.name -match 'config'}).path

# $bytes = [System.Text.Encoding]::Unicode.GetBytes( ($txt -ireplace 'Export-ModuleMember -Variable \*', '') + (Get-Command Add-Junctions).Definition )

# $encodedCommand = [Convert]::ToBase64String($bytes)

# $decodedCommand = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($encodedCommand))

# $decodedCommand | Out-File -Encoding unicode -FilePath ./qweewq.ps1
