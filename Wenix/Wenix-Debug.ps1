Import-Module -Force Wenix
Get-Module -Name Wenix


Import-UpdatedWenix

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