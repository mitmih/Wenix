<#
чтобы кириллическая строка корректно присваиваивалась переменной
текст скрипта должен быть в кодировке UTF-16 LE (1200 utf-16 Unicode)
    https://docs.microsoft.com/ru-ru/powershell/scripting/components/vscode/understanding-file-encoding?view=powershell-6
    
    # $UTF8BOM__no = New-Object System.Text.UTF8Encoding $false
    # $UTF8BOM_yes = [System.Text.UTF8Encoding]($true)
    # # перекодировка фа utf8_BOM >>> utf8_no_BOM
    # $text = [System.IO.File]::ReadAllLines(".\base64.inverted.csv", $UTF8BOM_yes)
    # [System.IO.File]::WriteAllLines(".\base64.inverted.csv", $text, $UTF8BOM__no)
 #>


Clear-Host

Set-Location "$($MyInvocation.MyCommand.Definition | Split-Path -Parent)"


$u16 = [System.Text.Encoding]::Unicode

$file = Import-Csv -Path ".\BootStrap.csv"

foreach ($s in $file)  # инверсия между открытым текстом и base64
{
    try   { $s.user = $u16.GetString([System.Convert]::FromBase64String($s.user    )) }  # либо раз-base64-им
    catch { $s.user = [System.Convert]::ToBase64String($u16.GetBytes($s.user)) }         # либо за-base64-им
    
    try   { $s.password = $u16.GetString([System.Convert]::FromBase64String($s.password)) }
    catch { $s.password = [System.Convert]::ToBase64String($u16.GetBytes($s.password)) }
    
    Write-Host $s.user, $s.password
}

$file | Export-Csv -NoTypeInformation -Path ".\BootStrap.csv" -Encoding Unicode
