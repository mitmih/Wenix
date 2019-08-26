Import-Module -Force Wenix

$file = Find-NetConfig

$shares = @()
if ($null -ne $file) { $shares += Read-NetConfig -file $file } # else { $shares = @() }

# $ok = @{} ; $ver = '10' ; $name = 'install'
if ($shares.Count -gt 0)
{
    # PE
    $ver = 'PE' ; $name = 'boot'
    $PEshares = Test-WimNet -SharesList $shares -ver $ver -name $name -md5
    
    # OS
    $ver = '10' ; $name = 'install'
    $OSshares = Test-WimNet -SharesList $shares -ver $ver -name $name -md5
}

$PEshares
"`n"
$OSshares