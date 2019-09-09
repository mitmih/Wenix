$volumes = @(  # схема разбивки ЖД
    # Active (bootmgr) + winPE RAM-disk + wim-files storage
    New-Object psobject -Property @{ letter = [char]'B' ; label =   'PE' ; size = 25GB ; active = $true}
    
    # for windows
    New-Object psobject -Property @{ letter = [char]'O' ; label =   'OS' ; size = 75GB ; active = $false}
    
    # user data, will be resized to max
    New-Object psobject -Property @{ letter = [char]'Q' ; label = 'Data' ; size = 0    ; active = $false}
)


$BootStrap = '.IT\PE\BootStrap.csv'  # NetWork Shares access configuration file


$ModulePath = '.IT\PE\Wenix'  # NetWork Shares access configuration file


Export-ModuleMember -Variable *  # 'volumes', 'BootStrap'
