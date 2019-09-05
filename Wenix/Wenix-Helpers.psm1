function Show-Menu  # отображает меню
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


function Find-NetConfig  # ищет на локальных разделах сетевой конфиг '<буква_диска>:\.IT\PE\BootStrap.csv'
# можно улучшить и возвращать самый свежий в случае нескольких найденных, либо объединять в список
{
    param ()
    
    
    begin { $res = @() }
    
    process
    {
        foreach ($v in (Get-Volume | Where-Object {$null -ne $_.DriveLetter} | Sort-Object -Property DriveLetter) )  # поиск в алфавитном порядке C: D: etc
        {
            $p = $v.DriveLetter + ':\' + $BootStrap
            
            if (Test-Path -Path $p) { $res += Get-Item -Path $p }
        }
    }
    
    end { return ($res | Sort-Object -Property 'LastWriteTime' -Descending | Select-Object -First 1) }
}


function Get-VacantLetters  # возвращает список свободных букв для подключения сетевых шар
{
    param ()
    
    $total = @(
        'A'
        'B'
        'C'
        'D'
        'E'
        'F'
        'G'
        'H'
        'I'
        'J'
        'K'
        'L'
        'M'
        'N'
        'O'
        'P'
        'Q'
        'R'
        'S'
        'T'
        'U'
        'V'
        'W'
        'X'
        'Y'
        'Z'
    )
    
    $busy = Get-PSDrive -PSProvider FileSystem | Where-Object {$null -ne $_.Name -and ($_.Name).Length -lt 2}
    
    $vacant = $total | Where-Object {$busy.Name -inotcontains $_ -and $volumes.letter -inotcontains $_}

    return $vacant
}


function Read-NetConfig  # читает конфиг сетевых источников, фильтрует по шлюзу, возвращает те, к которым удалось подключиться
{
    param (
        [alias('i')]
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$file,
        
        $limit = 2,
        
        $TimeOut = 999  # в миллисекундах
    )
    
    
    begin
    {
        $shares = @()  # список сетевых папок, отфильтрованный по назначенным шлюзам
        
        $valid = @()  # список рабочих сетевых шар
        
        $GWs = @()  # список ip-адресов шлюзов
        
        Start-Process -Wait -FilePath 'wpeutil' -ArgumentList 'WaitForNetwork'  # ожидание инициализации сети
        
        foreach ($item in (ipconfig | Select-String -Pattern 'ipv4' -Context 0,2))
        {
            if (($item.Context.PostContext[1].Split(':')[1].Trim()).Length -gt 0) { $GWs += $item.Context.PostContext[1].Split(':')[1].Trim() }
        }
        
        $NetDriveLetters = Get-VacantLetters  # если вдруг все буквы окажутся занятыми - нужно отключать лишнее оборудование (кард-ридеры напр.)
        
        $limit = $NetDriveLetters.Count
    }
    
    process
    {
            foreach ($gw in $GWs) { $shares += Import-Csv -Path $file -ErrorAction Stop | Where-Object { $_.gw -match $gw} }
            
            $n = 0  # index of current letter in $NetDriveLetters
            
            foreach ( $s in ($shares | Select-Object -First $limit) )
            {
                try
                {
                    $tcp = New-Object Net.Sockets.TcpClient
                    
                    $connect = $tcp.BeginConnect( ($s.netpath.Split('\')[2]), 445, $null, $null)
                }
                catch {}
                
                if ($connect.AsyncWaitHandle.WaitOne($TimeOut,$false))  # таймаут по-умолчанию 999 миллисекунд
                {
                    $tcp.EndConnect($connect) | Out-Null
                    
                    $v = $s | Select-Object -Property *, 'PSDrive'
                    
                    $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $v.user, (ConvertTo-SecureString $v.password -AsPlainText -Force)
                    
                    try
                    {
                        $drive = New-PSDrive -PSProvider FileSystem -NAME $NetDriveLetters[$n] -Persist -Scope 'Global' <# (Get-Random) #> -Root $v.netpath -Credential $cred -ErrorAction Stop
                        
                        $n++
                    }
                    catch  # [System.ComponentModel.Win32Exception]
                    {
                        # "$($v.netpath) does NOT EXIST" | Out-Default
                    }
                    
                    if ([System.IO.Directory]::Exists($v.netpath))
                    {
                        $v.PSDrive = $drive.Name
                        
                        $valid += $v
                        
                    }
                }
            }
    }
    
    end { return $valid }
}


function Test-Disk  # проверяет ЖД на соответствие $volumes (метки и кол-во разделов), + стиль разметки MBR
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
            try
            {
                $CheckList[$v.label] = (Get-Partition -ErrorAction Stop -DiskNumber $pos | Get-Volume).FileSystemLabel -icontains $v.label
            }
            
            catch
            {
                $CheckList[$v.label] = $false
            }
        }
        
        
        try
        {
            $CheckList['partition count']= (Get-Partition -ErrorAction Stop -DiskNumber $pos).Length -eq $volumes.Count
            
            $CheckList['partition table']= (Get-Disk -ErrorAction Stop -Number $pos).PartitionStyle -match 'MBR'
        }
        
        catch
        {
            $CheckList['Disk has been Initialized'] = $false
        }
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


function Test-Wim  # ищет / проверяет / возвращает проверенные по md5 источники wim-файлов
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
                
                $v.date2mod = $file.LastWriteTime  #Utc  # LastWriteTimeUtc  # дата изменения содержания файла, сохраняется при копировании файла - используется для выбора самого свежего wim-файла (предположительно в процессе deploy`я wim-файлов этот атрибут сохранится)
                
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
            
            
            if ($CheckListWim.Values -contains $true) { Write-Host ("    OK        {0,-66}" -f $v.FilePath) -BackgroundColor DarkGreen } # вывод в консоль успешных проверок
            
            
            $valid += $v | Where-Object {$_.FileExist -eq $true -and $_.md5ok -eq $true}  # список проверенных источников файлов
        }
    }
    
    end { return $valid }
}


function Edit-PartitionTable  # очищает диск полностью и пересоздаёт разделы согласно $volumes
{
    param ( $pos = 0 )
    
    
    begin { $res = $false }
    
    process
    {
        try
        {
            if ('RAW' -eq (Get-Disk -Number 0).PartitionStyle)
            # чистый диск - нужно инициализировать
            {
                Initialize-Disk -Number $pos -PartitionStyle MBR
            }
            else
            # диск размечен
            {
                Clear-Disk -Number $pos -RemoveData -RemoveOEM -Confirm:$false
                
                Initialize-Disk -Number $pos -PartitionStyle MBR
            }
            
            
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
        
        catch { $res = $false }
    }
    
    end { return $res }
}


function Install-Wim  # равёртывает wim-файлы: PE boot.wim -> на раздел 'PE', install.wim -> 'OS'
{
    param ($ver = ''<# , [switch]$PE = $false #>)
    
    
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
                $null = Expand-WindowsImage -ImagePath "$PEletter\.IT\PE\boot.wim" -ApplyPath "$PEletter\" -Index 1 -Verify -ErrorAction Stop
                
                Start-Process -Wait -FilePath "$env:windir\System32\BCDboot.exe" -ArgumentList "$PEletter\Windows", "/s $PEletter", "/f ALL"
                
                
                # make RAM Disk object
                bcdedit /create '{ramdiskoptions}' /d 'Windows PE RAM Disk' | Out-Null
                bcdedit /set    '{ramdiskoptions}' ramdisksdidevice "partition=$PEletter" | Out-Null
                bcdedit /set    '{ramdiskoptions}' ramdisksdipath '\.IT\PE\boot.sdi' | Out-Null
                (bcdedit /create /d "Windows PE RAM Disk" /application osloader) -match '\{.*\}' | Out-Null  # "The entry '{e1679017-bc5a-11e9-89cf-a91b7c7227b0}' was successfully created."
                $guid = $Matches[0]
                
                # make OS loader object
                bcdedit /set $guid   device "ramdisk=[$PEletter]\.IT\PE\boot.wim,{ramdiskoptions}" | Out-Null
                bcdedit /set $guid osdevice "ramdisk=[$PEletter]\.IT\PE\boot.wim,{ramdiskoptions}" | Out-Null
                bcdedit /set $guid path '\Windows\System32\Boot\winload.exe' | Out-Null
                bcdedit /set $guid systemroot '\Windows' | Out-Null
                bcdedit /set $guid winpe yes | Out-Null
                bcdedit /set $guid detecthal yes | Out-Null
                
                bcdedit /displayorder $guid /addfirst | Out-Null  # + PE RAM-disk boot menu entry
                bcdedit /delete '{default}' /cleanup | Out-Null
                
                $res = $true
            }
            elseif ( (Test-Path -Path "$PEletter\.IT\$ver\install.wim") )
            {
                $null = Format-Volume -FileSystemLabel 'OS' -NewFileSystemLabel 'OS' -ErrorAction Stop  # из-за ошибки "Access denied" при установке 10ки на 10ку
                
                $null = Expand-WindowsImage -ImagePath "$PEletter\.IT\$ver\install.wim" -ApplyPath "$OSletter\" -Index 1 <# -Verify #> -ErrorAction Stop
                
                # Start-Process -Wait -FilePath 'dism.exe' -ArgumentList '/Apply-Image', "/ImageFile:$PEletter\.IT\$ver\install.wim", "/ApplyDir:$OSletter\", '/Index:1'
                
                bcdedit /delete '{default}' /cleanup | Out-Null  # remove default entry (boot PE from HD or old OS), leave only RAMDisk`s entry
                
                Start-Process -Wait -FilePath "$env:windir\System32\BCDboot.exe" -ArgumentList "$OSletter\Windows"
                
                $res = $true
            }
            else { $res = $false }
        }
        
        catch { $res = $false }
    }
    
    end { return $res }
}


function Copy-WithCheck  # копирует из папки в папку с проверкой md5
{
    param ( $from, $to, $retry = 2, $net = $null )
    
    
    if ($from.Trim() -eq $to.Trim()) { return $true }
    
    $res = @()
    
    try
    {
        $filesFrom = (Get-ChildItem -Path $from -Recurse -Force -ErrorAction Stop | Get-FileHash -Algorithm MD5 -ErrorAction Stop)
        
        if( !(Test-Path -Path $to) ) { New-Item -ItemType Directory -Path $to -ErrorAction Stop}
        
        for ($i = 0; $i -lt $retry; $i++)  # несколько попыток копирования
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
    
    catch { $res += $false }
    
    finally
    {
        $res = $res -notcontains $false
    
        Write-Host ( '    {0,-4} copy {1,-40} >>> {2,21}' -f $(if ($res) {'OK'} else {'FAIL'}), $from, $to) -BackgroundColor $(if ($res) {'DarkGreen'} else {'DarkRed'})
    }
    
    return $res
}


function Reset-OpticalDrive  # отключение виртуального привода
{
    param ()
    
    
    try
    {
        $ComRecorder = New-Object -ComObject 'IMAPI2.MsftDiscRecorder2'
        
        $ComRecorder.InitializeDiscRecorder( (New-Object -ComObject 'IMAPI2.MsftDiscMaster2') )
        
        $ComRecorder.EjectMedia()
        
        $ComRecorder.CloseTray()
    }
    
    catch { $_ | Out-Null }
    
    return $null
}


function Set-NextBoot  # перезагрузка в дефолт-пункт (чтобы не ловить момент когда нужно установочную флешку отключить, а иначе она снова грузится)
{
    param ()
    
    
    foreach ($v in (Get-Partition -DiskNumber 0 | Where-Object {$_.DriveLetter} | Sort-Object -Property DriveLetter) )  # поиск в алфавитном порядке C: D: etc
    {
        $p = $v.DriveLetter + ':\Boot\BCD'
        
        if (Test-Path -Path $p)
        {
            $bcd = Get-Item -Force -Path $p
            
            break
        }
    }
    
    # bcdedit /set '{fwbootmgr}' bootsequence '{<uniq_guid>}' /addfirst
    # bcdedit /bootsequence '{<uniq_guid>}'
    
    bcdedit /store $bcd.FullName /bootsequence '{default}' | Out-Null
}


function Add-Junctions  # junction-ссылки на папки .IT и .OBMEN c загрузочного раздела
{
    param ()
    
    
    try
    {
        $guidOS = (Get-Volume -FileSystemLabel 'OS').Path
                        
        $guidPE = (Get-Volume -FileSystemLabel 'PE').Path
        
        
        if (Test-Path -Path ($guidOS + '.IT')) { Remove-Item -Recurse -Force -Path ($guidOS + '.IT') }
        
        if (Test-Path -Path ($guidPE + '.IT'))  # создаёт junction-ссылку на '.IT' с загрузочного раздела на разделе с ОС, используя UNC пути
        {
            Start-Process -FilePath "cmd.exe" -ArgumentList '/c','mklink', '/J', ($guidOS + '.IT'), ($guidPE + '.IT')
        }
        
        
        if (Test-Path -Path ($guidOS + '.OBMEN')) { Remove-Item -Recurse -Force -Path ($guidOS + '.OBMEN') }
        
        if (Test-Path -Path ($guidPE + '.OBMEN'))  # создаёт junction-ссылку на '.OBMEN' с загрузочного раздела на разделе с ОС, используя UNC пути
        {
            Start-Process -FilePath "cmd.exe" -ArgumentList '/c','mklink', '/J', ($guidOS + '.OBMEN'), ($guidPE + '.OBMEN')
        }
    }
    
    catch { $_ }
    
    
    return $res
}
