Clear-Host

$current_dir = $MyInvocation.MyCommand.Definition | Split-Path -Parent ; Set-Location "$current_dir"


$UTF8BOM__no = New-Object System.Text.UTF8Encoding $false

$UTF8BOM_yes = New-Object System.Text.UTF8Encoding $true


$file = Import-Csv -Path "$current_dir\base64.csv"

foreach ($s in $file)  # инверсия между открытым текстом и base64
{
    try   { $s.user = $UTF8BOM__no.GetString([System.Convert]::FromBase64String($s.user    )) }  # либо раз-base64-им
    catch { $s.user = [System.Convert]::ToBase64String($UTF8BOM__no.GetBytes($s.user)) }         # либо за-base64-им
    
    try   { $s.password = $UTF8BOM__no.GetString([System.Convert]::FromBase64String($s.password)) }
    catch { $s.password = [System.Convert]::ToBase64String($UTF8BOM__no.GetBytes($s.password)) }
    
    Write-Host $s.user, $s.password
}

$file | Export-Csv -NoTypeInformation -Path "$current_dir\base64.inverted.csv" -Encoding UTF8


# перекодировка utf8_BOM >>> utf8_no_BOM

$text = [System.IO.File]::ReadAllLines("$current_dir\base64.inverted.csv", $UTF8BOM_yes)

[System.IO.File]::WriteAllLines("$current_dir\base64.inverted.csv", $text, $UTF8BOM__no)
