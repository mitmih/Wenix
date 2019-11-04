# для работы скрипта требуется KB2693643 ( RSAT, Средства удаленного администрирования сервера для Windows 10)
#   https://www.microsoft.com/ru-RU/download/details.aspx?id=45520

param
(
    $Filter = $null
)

Clear-Host

Set-Location "$($MyInvocation.MyCommand.Definition | split-path -parent)"

$laps = @()

$OUs = Import-Csv -Path '.\New-NetConfig_AD.csv'

foreach ($ou in $OUs)
{
    $laps += Get-ADComputer -Properties 'Name', 'ms-Mcs-AdmPwd' -SearchBase $ou.adpath -Filter {Enabled -eq $True} | Select-Object -Property 'Name', 'ms-Mcs-AdmPwd'
}

<#
# todo:
#     фильтрануть массив $laps именами компов - сетевых хранилищ установочных образов
# 
#     в цикле по отфильтрованным записям
#         закодировать логин/пароль в base64
#         сформировать и добавить в экспортный массив строку "gw","netpath","user","password"
# 
#     экспортировать данные в сетевой конфиг
#         $qwe | Sort-Object -Property 'netpath' | Export-Csv -NoTypeInformation -Path '.\BootStrap.csv'
#>
