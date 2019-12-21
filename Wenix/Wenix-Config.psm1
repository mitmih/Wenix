$volumes = [ordered] @{  # схема разбивки ЖД
    # Active (bootmgr) + Wenix cache (winPE RAM-disk + wim-files storage)
    'VolPE' = New-Object psobject -Property @{ letter = [char]'B' ; size = 20GB ; active = $true  ; label = 'PE' }
    
    # windows volume
    'VolOS' = New-Object psobject -Property @{ letter = [char]'O' ; size = 80GB ; active = $false ; label = 'OS' }
    
    # user data, will be resized to max
    'VolUD' = New-Object psobject -Property @{ letter = [char]'Q' ; size = 0    ; active = $false ; label = 'Data' }
}


$DiskNumber = -1  # начиная с версии 2.1.4 диск выбирает пользователь

$BootStrap = '.IT\PE\BootStrap.csv'  # NetWork Shares access configuration file

$ModulePath = '.IT\PE\Wenix'  # Path for search newer module versions

$TimeOutBCDEdit = 5  # boot menu display timeout

$TimeOutAutoRun = 5  # post-install cmd-script timeout before self erasing


Export-ModuleMember -Variable *
