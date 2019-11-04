Clear-Host

$current_dir = $MyInvocation.MyCommand.Definition | Split-Path -Parent
Set-Location $current_dir

$UTF8BOM__no = New-Object System.Text.UTF8Encoding $false
$UTF8BOM_yes = New-Object System.Text.UTF8Encoding $true

$file = Import-Csv -Path '.\base64.csv'

foreach ($s in $file)
{
    try   { $s.user = $UTF8BOM__no.GetString([System.Convert]::FromBase64String($s.user    )) }  # если ещё не в base64
    catch { $s.user = [System.Convert]::ToBase64String($UTF8BOM__no.GetBytes($s.user)) }         # то закодируем
    
    try   { $s.password = $UTF8BOM__no.GetString([System.Convert]::FromBase64String($s.password)) }
    catch { $s.password = [System.Convert]::ToBase64String($UTF8BOM__no.GetBytes($s.password)) }
    
    Write-Host $s.user, $s.password
}


$file | Export-Csv -NoTypeInformation -Path '.\base64.inverted.csv' -Encoding UTF8
sleep -Milliseconds 333

# перекодировка utf8_BOM >>> utf8_no_BOM
$text = [System.IO.File]::ReadAllLines('.\base64.inverted.csv', $UTF8BOM_yes)
[System.IO.File]::WriteAllLines('.\base64.inverted.csv', $text, $UTF8BOM__no)
