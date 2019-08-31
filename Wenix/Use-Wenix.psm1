$volumes = @(
    New-Object psobject -Property @{ letter = [char]'B' ; label =   'PE' ; size = 25GB ; active = $true}  # Active, bootmgr + winPE RAM-disk
    New-Object psobject -Property @{ letter = [char]'O' ; label =   'OS' ; size = 75GB ; active = $false}  # for windows
    New-Object psobject -Property @{ letter = [char]'Q' ; label = 'Data' ; size = 0 ; active = $false}  # for data, will be resized to max
)


$NetDrv = @(
    'R'
    'S'
    'T'
    'U'
    'V'
    'W'
)


function Show-Menu
{
<#
.SYNOPSIS
    Show possible actions menu

.DESCRIPTION
    user can interact with Wenix by pressing keys
        <--     break menu script
        Esc     reboot
        0       re-install Windows 10
        7       re-install Windows 7

.INPUTS
    # 

.OUTPUTS
    pressed key

.EXAMPLE
    $k = Show-Menu

.LINK
    https://github.com/mitmih/wenix

.NOTES
    Author: Dmitry Mikhaylov aka alt-air
#>
    
    param ()
    
    begin
    {
        $MenuText = @(
            ""
            "Wenix version $((Get-Module -Name Wenix).Version.ToString())"
            ""
            "Please press specified key to select action:"
            ""
            "   <--     escape from menu"
            "   Esc     reboot"
            "   0       re-install Windows 10"
            "   7       re-install Windows 7"
            ""
        )
    }
    
    process { $MenuText | Out-Default }
    
    end { return [console]::ReadKey() }
}


function Test-Disk
{
    param (
        $pos = 0,
        [switch]$skip = $false
        )
    
    begin { $CheckList = [ordered]@{} }
    
    process
    {
        foreach ($v in $volumes)
        {
            $CheckList[$v.label] = (Get-Partition -DiskNumber $pos -ErrorAction Stop | Get-Volume).FileSystemLabel -icontains $v.label
        }
        
        
        $CheckList['partition count']= (Get-Partition -DiskNumber $pos).Length -eq $volumes.Count
        
        $CheckList['partition table']= (Get-Disk -Number $pos).PartitionStyle -match 'MBR'
    }
    
    end
    {
        if ($CheckList.Values -contains $true)
        {
            Write-Host ("    disk   OK   checks {0,57}" -f '') -BackgroundColor DarkGreen
            
            $CheckList.GetEnumerator() | Where-Object {$_.value -eq $true} | Out-Default
        }
        
        if ($CheckList.Values -contains $false)
        {
            Write-Host ('    disk FAILED checks {0,57}' -f '') -BackgroundColor DarkRed
            
            $CheckList.GetEnumerator() | Where-Object {$_.value -eq $false} | Out-Default
        }
        
        
        if ($skip) { return $true } else { return ( $CheckList.count -gt 0 -and $CheckList.Values -notcontains $false ) }
    }
}


function Edit-PartitionTable
{
    param ( $pos = 0 )
    
    
    begin { $res = $false }
    
    process
    {
        try
        {
            Clear-Disk -Number $pos -RemoveData -RemoveOEM -Confirm:$false
            
            Initialize-Disk -Number $pos -PartitionStyle MBR
            
            foreach ($v in $volumes)
            {
                $params = @{
                    'DiskNumber'  = $pos
                    'DriveLetter' = $v.letter
                    'ErrorAction' = 'Stop'
                    'IsActive'    = $v.active
                }
                if ($v.size -gt 0) {$params['Size'] = $v.size} else {$params['UseMaximumSize'] = $true}
                
                New-Partition @params | Format-Volume -FileSystem 'NTFS' -NewFileSystemLabel $v.label -ErrorAction Stop }
                
                $res = $true
        }
        
        catch
        {
            $res = $false
            
            <# $Error | Out-Default #>
        }
    }
    
    end { return $res }
}


function Install-Wim
{
    param ($ver = '', $wim = $null <# , [switch]$PE = $false #>)
    
    
    begin
    {
        $res = $false
        
        $PEletter = "$((Get-Volume -FileSystemLabel 'PE').DriveLetter):"
        
        $OSletter = "$((Get-Volume -FileSystemLabel 'OS').DriveLetter):"
    }
    
    process
    {
        try
        {
            if ( $ver -eq 'PE' -and (Test-Path -Path "$PEletter\.IT\PE\boot.wim") )
            {
                Expand-WindowsImage -ImagePath "$PEletter\.IT\PE\boot.wim" -ApplyPath "$PEletter\" -Index 1 -Verify -ErrorAction Stop
                
                Start-Process -Wait -FilePath "$env:windir\System32\BCDboot.exe" -ArgumentList "$PEletter\Windows", "/s $PEletter", "/f ALL"
                
                
                # make RAM Disk object
                bcdedit /create '{ramdiskoptions}' /d 'Windows PE, RAM DISK BOOT'
                bcdedit /set    '{ramdiskoptions}' ramdisksdidevice "partition=$PEletter"
                bcdedit /set    '{ramdiskoptions}' ramdisksdipath '\.IT\PE\boot.sdi'
                (bcdedit /create /d "Windows PE, RAM DISK LOADER" /application osloader) -match '\{.*\}'  # "The entry '{e1679017-bc5a-11e9-89cf-a91b7c7227b0}' was successfully created."
                $guid = $Matches[0]
                
                # make OS loader object
                bcdedit /set $guid   device "ramdisk=[$PEletter]\.IT\PE\boot.wim,{ramdiskoptions}"
                bcdedit /set $guid osdevice "ramdisk=[$PEletter]\.IT\PE\boot.wim,{ramdiskoptions}"
                bcdedit /set $guid path '\Windows\System32\Boot\winload.exe'
                bcdedit /set $guid systemroot '\Windows'
                bcdedit /set $guid winpe yes
                bcdedit /set $guid detecthal yes
                
                bcdedit /displayorder $guid /addfirst  # + PE RAM-disk boot menu entry
                bcdedit /delete '{default}' /cleanup
            }
            else #if ( Test-Path -Path "$PEletter\.IT\$ver\install.wim" )
            {
                "$wim" | Out-Default
                Format-Volume -FileSystemLabel 'OS' -NewFileSystemLabel 'OS' -ErrorAction Stop  # из-за ошибки "Access denied" при установке 10ки на 10ку
                
                Expand-WindowsImage -ImagePath "$PEletter\.IT\$ver\install.wim" -ApplyPath "$OSletter\" -Index 1 <# -Verify #> -ErrorAction Stop
                
                # Start-Process -Wait -FilePath 'dism.exe' -ArgumentList '/Apply-Image', "/ImageFile:$PEletter\.IT\$ver\install.wim", "/ApplyDir:$OSletter\", '/Index:1'
                
                bcdedit /delete '{default}' /cleanup  # remove default entry (boot PE from HD or old OS), leave only RAMDisk`s entry
                
                Start-Process -Wait -FilePath "$env:windir\System32\BCDboot.exe" -ArgumentList "$OSletter\Windows"
            }
            
            $res = $true
        }
        
        catch
        {
            $res = $false
            
            <# $Error | Out-Default #>
        }
    }
    
    end { return $res }
}


function Find-NetConfig  # можно улучшить и возвращать самый свежий в случае нескольких найденных, либо объединять в список
# ищет на локальных разделах сетевой конфиг '<буква_диска>:\.IT\PE\BootStrap.csv'
{
    param ()
    
    
    begin { $res = $null }
    
    process
    {
        foreach ($v in (Get-Volume | Where-Object {$null -ne $_.DriveLetter} | Sort-Object -Property DriveLetter) )  # поиск в алфавитном порядке C: D: etc
        {
            $p = $v.DriveLetter + ':\.IT\PE\BootStrap.csv'
            
            if (Test-Path -Path $p)
            {
                $res = Get-Item -Path $p
                
                break
            }
        }
    }
    
    end { return $res }
}


function Read-NetConfig
# читает конфиг сетевых источников, фильтрует по шлюзу, возвращает те, к которым удалось подключиться
{
    param ($file)
    
    
    begin
    {
        $shares = @()  # список сетевых папок, отфильтрованный по назначенным шлюзам
        
        $valid = @()  # список рабочих сетевых шар
        
        $GWs = @()  # список ip-адресов шлюзов
        
        # Start-Process -FilePath 'wpeutil' -ArgumentList 'WaitForNetwork' -Wait  # ожидание инициализации сети
        
        foreach ($item in (ipconfig | Select-String -Pattern 'ipv4' -Context 0,2))
        {
            if (($item.Context.PostContext[1].Split(':')[1].Trim()).Length -gt 0) { $GWs += $item.Context.PostContext[1].Split(':')[1].Trim() }
        }
        
        foreach ($n in $NetDrv)
        {
            if (Get-PSDrive | ? {$_.Name -eq $n})
            {
                # Remove-PSDrive -Name $n -Force -Scope Global  # doesn`t work!!!
                Start-Process -FilePath 'net.exe' -ArgumentList 'use', ($n + ':'), '/delete'
            }
        }
    }
    
    process
    {
        try
        {
            foreach ($gw in $GWs) { $shares += Import-Csv -Path $file -ErrorAction Stop | Where-Object { $_.gw -match $gw} }
            
            $l = 0
            foreach ( $s in ($shares | Select-Object -First $NetDrv.Count) )
            {
                # if (Test-Connection -Quiet -Count 3 -ComputerName $s.netpath.Split('\')[2])
                if (Test-NetConnection -InformationLevel Quiet -Port 445 -ComputerName $s.netpath.Split('\')[2])
                # $c = New-Object Net.Sockets.TcpClient
                # $c.ReceiveTimeout = 10
                # $c.Connect( ($s.netpath.Split('\')[2]), 445)
                # if ($c.Connected)
                {
                    $v = $s | Select-Object -Property *, 'PSDrive'
                    
                    $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $v.user, (ConvertTo-SecureString $v.password -AsPlainText -Force)
                    
                    $drive = New-PSDrive -Persist -NAME $NetDrv[$l] -PSProvider FileSystem -Root $v.netpath -Credential $cred -ErrorAction Stop
                    
                    if ([System.IO.Directory]::Exists($s.netpath))
                    {
                        $l++
                        $v.PSDrive = $drive.Name
                        $valid += $v
                    }
                    else { $drive | Remove-PSDrive }
                }
            }
        }
        
        catch { <# $Error | Out-Default #> }
    }
    
    end { return $valid }
}


function Test-Wim
# ищет / проверяет / возвращает проверенные по md5 источники wim-файлов
{
    [CmdletBinding()]
    
    param (
        $SharesList = $null,  # список сетевых папок ($null означает поиск / проверку локальных файлов)
        
        $ver,  # 7 / 10 / PE
        
        $name, # boot / install
        
        $exclude = @(),  # буквы исключаемых из локальной проверки разделов диска 0 - при переразметке диска источник файлов исчезнет
        
        [switch] $md5 = $false  # включить проверку md5
    )
    
    
    begin
    {
        $valid = @()  # список сетевых шар: <имя>.wim доступен по пути ...\.IT\<версия_ОС>, его md5 совпадает с хэшем из <имя>.wim.md5
        
        $local = $null -eq $SharesList  # показатель локальности поиска и проверок (в параметрах не передан список сетевых папок)
    }
    
    # логика поиска/контроля wim/md5 файлов на сетевых шарах подойдёт с минимальными изменениями и для локального PE раздела - нужно лишь превратить его в итерируемый объект (массив) с определёнными полями, тогда цикл с проверками не нужно будет дублировать для локального случая
    process
    {
        if ($local)  # формируем (одинаковую с сетевой) локальную коллекцию для проверки
        {
            $places = @()
            
            foreach ($lv in (Get-Volume | Where-Object {$null -ne $_.DriveLetter -and $exclude -inotcontains $_.DriveLetter}))
            # локальная коллекция
            {
                $places += (New-Object psobject -Property @{
                        "gw"        = $null
                        'netpath'   = ($lv.DriveLetter + ':')
                        "user"      = $null
                        "password"  = $null
                        "PSDrive"   = $lv.DriveLetter
                    })
            }
        }
        else { $places = $SharesList }  # сетевая коллекция
        
        
        foreach ($s in $places)  # цикл проверок коллекции: наличие wim и md5 файлов, корректность md5
        {
            $CheckListWim = [ordered]@{}  # одноразовый чек-лист, вывод для наглядности на Out-Default
            
            if (!$local)
            {
                $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $s.user, (ConvertTo-SecureString $s.password -AsPlainText -Force)
                
                $drive = New-PSDrive -NAME ($ver + '_' + $name + '_wim') -PSProvider FileSystem -Root $s.netpath -Credential $cred <# -ErrorAction Stop #>
            }
            
            
            $OSdir = $s.netpath + "\.IT\$ver"
            
            $v = $s | Select-Object -Property *, 'OS', 'FileName', 'FileExist', 'md5ok', 'date2mod', 'Priority', 'FilePath', 'FileSize', 'Root'  # замена конструкции 'Add-Member -Force', т.к. Add-Member изменяет исходный объект и при повторном вызове этой же функции без форсирования валятся ошибки, что такое NoteProperty уже существует
            
            $v.OS = $ver  # 7 / 10 / PE
            
            $v.FileName = "$name.wim"  # boot / install
            
            $v.FileExist = Test-Path -Path "$OSdir\$name.wim"
            
            $CheckListWim[("$name wim`t" + $s.netpath)] = $v.FileExist
            
            
            if ($v.FileExist)
            {
                $file = Get-Item -Path "$OSdir\$name.wim"
                
                $v.FilePath = $file.FullName
                
                $v.FileSize = ('{0,6:N0} MB' -f ($file.Length / 1MB))
                
                $v.date2mod = $file.LastWriteTimeUtc  # LastWriteTime это метка изменения содержимого файла и она сохраняется при копировании, т.е. если в процессе deploy`я wim-файлов по конечным сетевым папкам и дискам этот атрибут сохранится - его можно использовать для выбора самого свежего файла для развёртывания
                
                $v.Priority = if ($local) {0} else {1}  # приоритет при выборе источника будет выше у локальных файлов
                
                $v.Root = $OSdir
                
                if ($md5)  # проверка md5 если есть контролька
                {
                    if (Test-Path -Path "$OSdir\$name.wim.md5")
                    {
                        $md5file = Get-Content -Path "$OSdir\$name.wim.md5" | Select-String -Pattern "$name.wim"
                        
                        $md5file = $md5file.ToString().Split(' ')[0] #'^[a-zA-Z0-9]'
                        
                        $md5calc = Get-FileHash -Path "$OSdir\$name.wim" -Algorithm MD5
                        
                        $v.md5ok = $md5file -ieq $md5calc.Hash
                    }
                    else { $v.md5ok = $false }
                    
                    
                    $CheckListWim[("$name md5`t" + $s.netpath)] = $v.md5ok
                }
                else
                {
                    $v.md5ok = $true
                    
                    $CheckListWim[("$name md5`t" + $s.netpath)] = $v.md5ok
                }
            }
            
            
            if ($CheckListWim.Values -contains $true) { Write-Host ("    OK          {0,-64}" -f $v.FilePath) -BackgroundColor DarkGreen } # вывод в консоль успешных проверок
            
            
            $valid += $v | Where-Object {$_.FileExist -eq $true -and $_.md5ok -eq $true}  # список проверенных источников файлов
            
            
            if ( !$local -and $drive ) { $drive | Remove-PSDrive ; $drive = $null }  # отключение сетевого диска
        }
    }
    
    end { return $valid }
}


function Copy-WithCheck
# копирует из папки в папку с проверкой md5, сетевые диски подключает
{
    param ( $from, $to, $retry = 2, $net = $null )
    
    begin
    {
        $res = @()
        
        if ($null -ne $net)
        {
            $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $net.user, (ConvertTo-SecureString $net.password -AsPlainText -Force)
            
            $drive = New-PSDrive -NAME 'T' -PSProvider FileSystem -Root $net.netpath -Credential $cred -ErrorAction Stop
        }
        else { $drive = $null }
        
        $filesFrom = (Get-ChildItem -Path $from -Recurse -Force | Get-FileHash -Algorithm MD5)
    }
    
    process
    {
        try
        {
            if( !(Test-Path -Path $to) ) { New-Item -ItemType Directory -Path $to -ErrorAction Stop}
            
            for ($i = 0; $i -lt $retry; $i++)  # множественные попытки копирования
            {
                foreach ($file in $filesFrom)
                {
                    $name = $file[0].Path.Split('\')[-1]
                    
                    Copy-Item -Force -Path $file.Path -Destination "$to\$name" -ErrorAction Stop
                    
                    $res += (Get-FileHash -Algorithm MD5 -Path "$to\$name").Hash -eq $file.Hash
                }
                
                if ($res -notcontains $false) { break }  # копирование было успешным
            }
        }
        
        catch
        {
            $res += $false
            
            <# $Error | Out-Default #>
        }
        
        $res = $res -notcontains $false

        Write-Host ( '{0,-5}copy to {1,-12}from {2,24} {3,24}' -f $(if ($res) {'OK'} else {'FAIL'}), $to, $from, '' ) -BackgroundColor $(if ($res) {'DarkGreen'} else {'DarkRed'})
    }
    
    end
    {
        if ($drive) { $drive | Remove-PSDrive }
        
        return $res
    }
}


function Use-Wenix
{
    param ([switch]$STOP = $false)
    
    begin
    {
        $WatchDogTimer = [system.diagnostics.stopwatch]::startNew()
        
        $log = [ordered]@{}
        
        $PEsourses = @()  # набор источников файлов для сортировки и выбора самого свежего wim-файла
        
        $OSsourses = @()  # набор источников файлов для сортировки и выбора самого свежего wim-файла
        
        $shares = @()
    }
    
    process
    {
        $cycle = $true ; while ( $cycle )
        {
            $key = Show-Menu
            
            switch ( $key.key )
            {
                { $_ -in @( 'D0', 'D7' ) }  # нажали 0 или 7
                {
                    Write-Host ("  <<<     selected{0,62}" -f "`n") -BackgroundColor Yellow -ForegroundColor Black
                    
                    if ($STOP) { Write-Host ("    MODE    STOP{0,64}" -f "`n") -BackgroundColor Yellow -ForegroundColor Black }
                    
                    Write-Host ("{0:N0} minutes`t{1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'installation process launched') #_#
                    
                    $ver = if ( $_ -eq 'D7' ) { '7' } else { '10' }  # на выбор Windows 7 / 10
                    
                    $Disk0isOk = Test-Disk
                    
                    
                    #region  сетевые источники
                    
                    $NetConfig = Find-NetConfig  # сетевой конфиг, должен лежать на томе ':\.IT\PE\BootStrap.csv', поиск в алфавитном порядке C: D: etc
                    
                    Write-Host ("{0:N0} minutes`t{1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Find-NetConfig BootStrap.csv') #_#
                    
                    
                    if ($null -ne $NetConfig)  # поиск wim-файлов в источниках из сетевого конфига ':\.IT\PE\BootStrap.csv'
                    {
                        $shares += Read-NetConfig -file $NetConfig
                        
                        Write-Host ("{0:N0} minutes`t{1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Read-NetConfig') #_#
                        
                        
                        $PEsourses += Test-Wim -md5 -ver 'PE' -name 'boot'    -SharesList $shares
                        
                        Write-Host ("{0:N0} minutes`t{1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Test-Wim NetWork PE') #_#
                        
                        
                        $OSsourses += Test-Wim -md5 -ver $ver -name 'install' -SharesList $shares
                        
                        Write-Host ("{0:N0} minutes`t{1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Test-Wim NetWork OS') #_#
                    }
                    
                    #endregion
                    
                    
                    #region локальные источники
                    
                    if (!$Disk0isOk) { $LettersExclude = (Get-Partition -DiskNumber 0 | Where-Object {'' -ne $_.DriveLetter}).DriveLetter }  # источники с этого диска бесполезны, т.к. ему нужна переразбивка
                    
                    $PEsourses += Test-Wim -md5 -ver 'PE' -name 'boot' #-exclude $LettersExclude
                    
                    Write-Host ("{0:N0} minutes`t{1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Test-Wim local PE') #_#
                    
                    
                    $OSsourses += Test-Wim -md5 -ver $ver -name 'install' -exclude $LettersExclude
                    
                    Write-Host ("{0:N0} minutes`t{1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Test-Wim local OS') #_#
                    
                    #endregion
                    
                    

                    if ( !($OSsourses.count -gt 0 -and $PEsourses.count -gt 0) )  # BUG HERE
                    # установка невозможна: один или оба источника wim-файлов пустые
                    {
                        $log['exist PE source'] = $OSsourses.count -gt 0
                        
                        $log['exist OS source'] = $PEsourses.count -gt 0
                    }
                    else
                    # можно начинать установку
                    {
                        $PEsourses = $PEsourses | Sort-Object -Property @{Expression = {$_.date2mod}; Descending = $true}, @{Expression = {$_.Priority}; Descending = $false}
                        
                        $OSsourses = $OSsourses | Sort-Object -Property @{Expression = {$_.date2mod}; Descending = $true}, @{Expression = {$_.Priority}; Descending = $false}
                        
                        
                        #region backup RAM-disk PE to memory
                        
                        $FTparams = @{
                            'Property' = @(  
                                'gw' , 
                                
                                'netpath'
                                'password'
                                'user'
                                # 'FileExist'
                                # 'md5ok'
                                'FilePath'
                                
                                'OS'
                                'Root'
                                'FileName'
                                'FileSize'
                                'date2mod'
                                'Priority'
                        )}
                        
                        ((@() + $PEsourses) + "`n" + (@() + $OSsourses)) | Select-Object @FTparams | Format-Table *
                        
                        
                        foreach ($wim in $PEsourses)
                        {
                            $copy = if ($null -eq $wim.user) { Copy-WithCheck -from $wim.Root -to 'X:\.IT\PE' } else { Copy-WithCheck -from $wim.Root -to 'X:\.IT\PE' -net $wim }
                            
                            $log['backup ramdisk in memory'] = $copy
                            
                            if ( $copy )
                            {
                                Copy-Item -Force -Path $NetConfig -Destination 'X:\.IT\PE'
                                
                                break
                            }
                        }
                        
                        if (!$log['backup ramdisk in memory']) { return }  # нет бэкапа RAM-диска - нет смысла продолжать т.к. не будет возможности восстановить загрузку хотя бы с PE
                        
                        if ($STOP) { return }  #################################
                        
                        #endregion
                        
                        
                        #region restore RAM-disk PE from memory, renew boot menu
                        
                        Write-Host ("{0:N0} minutes`t{1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Test-Disk') #_#
                        
                        if ( $Disk0isOk )  # remove all except .IT # overwrite with the latest found win PE boot.wim
                        {
                            Get-Item -Path "$((Get-Volume -FileSystemLabel 'PE').DriveLetter):\*" -Exclude '.IT' -Force | Remove-Item -Force -Recurse  # очистка тома 'PE' от старой non-ram PE
                            
                            Write-Host ("{0:N0} minutes`t{1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Mount-Standart') #_#
                        }
                        else  # clear disk # make partition
                        {
                            $log['Edit-PartitionTable'] = Edit-PartitionTable
                            
                            Write-Host ("{0:N0} minutes`t{1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Edit-PartitionTable') #_#
                        }
                        
                        if ( (Copy-WithCheck -from 'X:\.IT\PE' -to "$((Get-Volume -FileSystemLabel 'PE').DriveLetter):\.IT\PE") )
                        # copy PE back to the 'PE' volume # apply copied boot.wim to 'PE' volume
                        {
                            $log['Install-Wim PE'] = (Install-Wim -ver 'PE')
                            
                            Write-Host ("{0:N0} minutes`t{1} = {2}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Install-Wim -PE', $log['Install-Wim PE']) #_#
                        }
                        else { $log['restore RAM-disk from X:'] = $false }  # errors raised during copying - требуется внимание специалиста
                        
                        #endregion
                        
                        
                        #region apply install.wim to 'OS' volume
                        
                        foreach ($OSwim in $OSsourses)
                        {
                            $log['copying OS wim to PE volume'] = (Copy-WithCheck -from $OSwim.Root -to "$((Get-Volume -FileSystemLabel 'PE').DriveLetter):\.IT\$ver")
                            
                            if ( $log['copying OS wim to PE volume'] ) { break }
                        }
                        
                        $log['Install-Wim OS'] = (Install-Wim -ver $ver <# -wim $OSwim.FilePath #>)
                        
                        Write-Host ("{0:N0} minutes`t{1} = {2}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Install-Wim OS', $log['Install-Wim OS']) #_#
                        
                        #endregion
                    }
                    
                    
                    $log['debug'] = $false
                    if ($log.Values -notcontains $false) { Restart-Computer -Force } else { return }  # если все ок - перезагрузка, иначе - выход для отладки и ручных манипуляций
                }
                
                'Escape'
                {
                    Write-Host "ppress 'Y' to confirm exit"
                    
                    if (([console]::ReadKey()).key -eq 'Y') { Restart-Computer -Force }
                }
                
                'Backspace' { return }
                
                Default { break }
            }
        }
    }
    
    end {}
}
