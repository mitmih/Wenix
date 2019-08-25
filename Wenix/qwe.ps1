Import-Module -Force Wenix

$file = Find-NetConfig

$shares = @()
if ($null -ne $file) { $shares += Read-NetConfig -file $file } # else { $shares = @() }

$ok = @{}
if ($shares.Count -gt 0)
{
    for ($i = 0; $i -lt $shares.Count; $i++)
    {
        $ok[$i] = Test-WimNet -NetPath $shares[$i].netpath
    }
}

$ok