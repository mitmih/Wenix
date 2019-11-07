<#
# для работы скрипта требуется KB2693643 ( RSAT, Средства удаленного администрирования сервера для Windows 10)
#   https://www.microsoft.com/ru-RU/download/details.aspx?id=45520

скрипт собирает сетевой конфиг BootStrap.csv, необходимый Wenix`у для поиска установочных wim-образов на '-pc01' и '-pc02' компьютерах в конкретном офисе

сетевой конфиг может быть собран для как конкретного офиса (по-умолчанию), так и для всех офисов филиала (нужно вручную в скрипте закомментировать фильтрацию по имени целевого компа)

на целевом компе (где происходит переустановка ОС) Wenix по шлюзу отфильтрует список компов и будет искать установочные install.wim только в локальной сети

шлюз вычисляется по IP компьютера используя модуль IPCalc, исходя из следующих предположений:
    маска сети /27
    IP шлюза = IP сети + 1

напр. адрес компа 192.168.17.37, тогда
    адрес сети  192.168.17.32/27
               +            1
    адрес шлюза 192.168.17.33
#>
param
(
    [string] $FilterHostName = 'RU-MSC-LIB-PC93',  # $null
    [string] $FilterIP = '192.168.17.37/27'  # $null
)

Clear-Host

Import-Module IPCalc -Force

Set-Location "$($MyInvocation.MyCommand.Definition | Split-Path -Parent)"

$laps = @()

$OUs = Import-Csv -Path '.\New-NetConfig_AD.csv'  # конфиг OU`шек в Active Directory, содержащих УЗ рабочих станций - доноров установочных wim-образов 7-ки и 10-ки

foreach ($ou in $OUs)  # собираем LAPS-базу для сетевой авторизации в процессе переустановки
{
    $laps += Get-ADComputer -Properties 'Name', 'ms-Mcs-AdmPwd', 'ms-Mcs-AdmPwdExpirationTime' -SearchBase $ou.adpath -Filter {Enabled -eq $True} | `
        Select-Object -Property
            @{Name = 'PCName'; Expression = {$_.Name}},
            @{Name = 'PCPwd'; Expression = {$_.'ms-Mcs-AdmPwd'}},
            @{Name = 'PCPwdExpTime'; Expression = {$_.'ms-Mcs-AdmPwdExpirationTime'}} | Sort-Object -Property 'PCName'
}

$network = ($FilterIP + '/27' | Find-Networks).network  # предположение_1: маска по-умолчанию - /27

$gateway = ([IPAddress]([uint32]([IPAddress]$network).Address -bor [uint32]([ipaddress]('0.0.0.1')).Address)).IPAddressToString  # предположение_2: шлюзом выступает 1-й адрес в сети

$laps | Where-Object {$_.PCName -match ($FilterHostName.Substring(0,12) + '01') -or $_.PCName -match ($FilterHostName.Substring(0,12) + '02')}  # в роли доноров выступают 1-е и 2-е АРМ`ы


$BootStrap = @()  # собираем сетевой конфиг

foreach ($rec in $laps | Where-Object {$_.PCName -match ($FilterHostName.Substring(0,12) + '01') -or $_.PCName -match ($FilterHostName.Substring(0,12) + '02')})
{
    $BootStrap += (
        New-Object PSObject -Property @{ #"gw","netpath","user","password"
            gw          = $gateway
            netpath     = ('\\' + $rec.PCName + '\c$')
            user        = ($rec.PCName + '\администратор')  # без полноценного unicode кириллица превратится кашу на выходе
            password    = $rec.PCPwd
        }
    )
}

$BootStrap | Select-Object -Property "gw","netpath","user","password" | Export-Csv -NoTypeInformation -Encoding Unicode -Path '.\BootStrap.csv'

$BootStrap | Format-Table -Property *
