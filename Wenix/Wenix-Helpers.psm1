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
        if (Test-Path -Path $Global:WenixBootWimVerTempFile)
        {
            $ver = Get-Content $Global:WenixBootWimVerTempFile
        }
        else
        {
            $ver = '0.0.0.0'
        }
        
        $MenuText = @(
            ''
            "Wenix ramdisk version {0} was updated to {1}" -f $ver, (Get-Module -Name Wenix).Version.ToString()
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
    
    $vacant = $total | Where-Object {$busy.Name -inotcontains $_ -and $volumes.Values.letter -inotcontains $_}

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
                    
                    
                    # при необходимости учётные данные пользователя сетевой папки будут конвертированы из base64 в utf8-no-BOM
                    
                    # $UTF8NoBOM = New-Object System.Text.UTF8Encoding $false
                    $utf16le = [System.Text.Encoding]::Unicode  # файл с данными авторизации теперь хранит unicode-строки кодированные в base64, поэтому раскодировать их тоже нужно в unicode, иначе появляются ненужные байты между символами
                    
                    try { $s.user     = $utf16le.GetString([System.Convert]::FromBase64String($s.user    )) }
                    
                    catch {}
                    
                    try { $s.password = $utf16le.GetString([System.Convert]::FromBase64String($s.password)) }
                    
                    catch {}
                    
                    
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
# нужно добавить проверку размеров разделов
{
    param (
        [switch]$skip = $false
        )
    
    begin { $CheckList = [ordered]@{} }
    
    process
    {
        foreach ($v in $volumes.GetEnumerator())
        {
            try
            {
                $PartSize = (Get-Partition -DiskNumber $DiskNumber -ErrorAction Stop | Get-Volume | Where-Object {$_.FileSystemLabel -ieq $v.Value.label}).Size
            }
            
            catch
            {
                $CheckList[$v.Key] = $false
            }
            
            if ($PartSize)
            {
                $CheckList[$v.Key] = if ($v.Value.size -gt 0) {$v.Value.size -eq $PartSize } else { $false }
            }
            else { $CheckList[$v.Key] = $false }
        }
        
        
        try
        {
            $CheckList['partitions count']= (Get-Partition -ErrorAction Stop -DiskNumber $DiskNumber).Length -eq $volumes.Count
            
            $CheckList['partitions table']= (Get-Disk -ErrorAction Stop -Number $DiskNumber).PartitionStyle -match 'MBR'
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


function Edit-PartitionTable  # очищает диск полностью и размечает его на разделы согласно $volumes
{
    param ()
    
    
    begin { $res = $false }
    
    process
    {
        try
        {
            if ('RAW' -eq (Get-Disk -Number $DiskNumber).PartitionStyle)
            # чистый диск - нужно инициализировать
            {
                Initialize-Disk -Number $DiskNumber -PartitionStyle MBR
            }
            else
            # диск размечен
            {
                Clear-Disk -Number $DiskNumber -RemoveData -RemoveOEM -Confirm:$false
                
                Initialize-Disk -Number $DiskNumber -PartitionStyle MBR
            }
            
            
            foreach ($v in $volumes.GetEnumerator())
            {
                $params = @{
                    'DiskNumber'  = $DiskNumber
                    'DriveLetter' = $v.Value.letter
                    'ErrorAction' = 'Stop'
                    'IsActive'    = $v.Value.active
                }
                if ($v.Value.size -gt 0) {$params['Size'] = $v.Value.size} else {$params['UseMaximumSize'] = $true}
                
                New-Partition @params | Format-Volume -FileSystem 'NTFS' -NewFileSystemLabel $v.Value.label -ErrorAction Stop }
                
                $res = $true
        }
        
        catch { $res = $false }
    }
    
    end { return $res }
}


function Install-Wim  # равёртывает wim-файлы: PE boot.wim -> на том 'VolPE', install.wim -> 'VolOS'
{
    param ($ver = '')
    
    
    begin
    {
        $res = $false
        
        $PEletter = '{0}:' -f (Get-Partition -DiskNumber $DiskNumber | Get-Volume | Where-Object {$_.FileSystemLabel -eq $volumes['VolPE'].label}).DriveLetter
        
        $OSletter = '{0}:' -f (Get-Partition -DiskNumber $DiskNumber | Get-Volume | Where-Object {$_.FileSystemLabel -eq $volumes['VolOS'].label}).DriveLetter
        
        $bcd = $PEletter + '\Boot\BCD'
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
                bcdedit  /store $bcd /create '{ramdiskoptions}' /d 'Windows PE RAM Disk' | Out-Null
                bcdedit  /store $bcd /set    '{ramdiskoptions}' ramdisksdidevice "partition=$PEletter" | Out-Null
                bcdedit  /store $bcd /set    '{ramdiskoptions}' ramdisksdipath '\.IT\PE\boot.sdi' | Out-Null
                (bcdedit /store $bcd /create /d "Windows PE RAM Disk" /application osloader) -match '\{.*\}' | Out-Null  # "The entry '{e1679017-bc5a-11e9-89cf-a91b7c7227b0}' was successfully created."
                $guid = $Matches[0]
                
                # make OS loader object
                bcdedit  /store $bcd /set $guid   device "ramdisk=[$PEletter]\.IT\PE\boot.wim,{ramdiskoptions}" | Out-Null
                bcdedit  /store $bcd /set $guid osdevice "ramdisk=[$PEletter]\.IT\PE\boot.wim,{ramdiskoptions}" | Out-Null
                bcdedit  /store $bcd /set $guid path '\Windows\System32\Boot\winload.exe' | Out-Null
                bcdedit  /store $bcd /set $guid systemroot '\Windows' | Out-Null
                bcdedit  /store $bcd /set $guid winpe yes | Out-Null
                bcdedit  /store $bcd /set $guid detecthal yes | Out-Null
                
                bcdedit  /store $bcd /displayorder $guid /addfirst | Out-Null  # + PE RAM-disk boot menu entry
                bcdedit  /store $bcd /delete '{default}' /cleanup | Out-Null
                
                $res = $true
            }
            elseif ( (Test-Path -Path "$PEletter\.IT\$ver\install.wim") )
            {
                $null = Get-Partition -DiskNumber $DiskNumber | 
                    Get-Volume | 
                    Where-Object { $_.FileSystemLabel -eq $volumes['VolOS'].label} | 
                    Format-Volume -NewFileSystemLabel $volumes['VolOS'].label -ErrorAction Stop  # из-за ошибки "Access denied" при установке 10ки на 10ку
                
                $null = Expand-WindowsImage -ImagePath "$PEletter\.IT\$ver\install.wim" -ApplyPath "$OSletter\" -Index 1 <# -Verify #> -ErrorAction Stop
                
                # Start-Process -Wait -FilePath 'dism.exe' -ArgumentList '/Apply-Image', "/ImageFile:$PEletter\.IT\$ver\install.wim", "/ApplyDir:$OSletter\", '/Index:1'
                
                bcdedit  /store $bcd /delete '{default}' /cleanup | Out-Null  # remove default entry (boot PE from HD or old OS), leave only RAMDisk`s entry
                
                Start-Process -Wait -FilePath "$env:windir\System32\BCDboot.exe" -ArgumentList "$OSletter\Windows", "/s $PEletter", "/f ALL"
                
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
    param ( $from, $to, $retry = 2 )
    
    
    if ($from.Trim() -eq $to.Trim()) { return $true }
    
    
    try
    {
        $SourceFiles = (Get-ChildItem -Path $from -Recurse -Force -ErrorAction Stop | Get-FileHash -Algorithm MD5 -ErrorAction Stop)
        
        
        for ($i = 0; $i -lt $retry; $i++)  # несколько попыток копирования
        {
            $res = @()  # результаты сравнения md5 исходного и скопированного файлов, должны быть только $True
            
            
            foreach ($group in $SourceFiles | Split-Path -Parent | Group-Object)
            # готовим структуру папок 1-в-1
            {
                if ($from -eq $group.Name)  # корневая папка
                {
                    if ( !(Test-Path -Path $to) ) { New-Item -ItemType Directory -Path $to -ErrorAction Stop}
                }
                else  # вложенные папки
                {
                    $subdir = ( $to + $group.Name.Replace($from,'') )
                    
                    if ( !(Test-Path -Path $subdir) ) { New-Item -ItemType Directory -Path $subdir -ErrorAction Stop}
                }
            }
            
            
            foreach ($file in $SourceFiles)
            # копируем файлы 1-в-1
            {
                Copy-Item -Force -Path $file.Path -Destination ($to + $file.Path.Replace($from,'')) -ErrorAction Stop
                
                $res += ( Get-FileHash -Algorithm MD5 -Path ($to + $file.Path.Replace($from,'')) ).Hash -eq $file.Hash
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
    
    
    foreach ($v in (Get-Partition -DiskNumber $DiskNumber | Sort-Object -Property DriveLetter) )  # поиск в алфавитном порядке C: D: etc
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


function Add-Junctions  # алгоритм вычисления guid в 10й PE и в Windows 10 одинаковый - ссылки через UNC-пути сделанные из PE будут работать и в основной ОС
{
    try
    {
        # Get-Volume (и модуль Storage в целом) не работает в 7-ке, т.к. WMI не поддерживает нужные классы
        # поэтому, т.к. эта же функция используется в 7-ке через cmd-костыль, она реализована через Get-CimInstance
        # в кастомном install.wim установлен 5.1 PowerShell
        $guidPE = (Get-CimInstance -ClassName 'Win32_Volume' | Where-Object {$_.Label -eq $volumes['VolPE'].label}).DeviceID
        
        $guidOS = (Get-CimInstance -ClassName 'Win32_Volume' | Where-Object {$_.Label -eq $volumes['VolOS'].label}).DeviceID
        
        
        if (Test-Path -Path ($guidOS + '.IT')) { Remove-Item -Recurse -Force -Path ($guidOS + '.IT') }  # существующая (напр. развёрнута из wim-файла) папка помешает сделать ссылку
        
        if (Test-Path -Path ($guidPE + '.IT'))
        {
            # junction-ссылка с ОС-тома ведёт на '.IT' загрузочного раздела, пути в формате UNC
            Start-Process -FilePath "cmd.exe" -ArgumentList '/c','mklink', '/J', ($guidOS + '.IT'), ($guidPE + '.IT')
        }
    }
    
    catch { $_ }
    
    
    return $res
}


function Add-Junctions7  # в Windows 7 алгоритм назначения guid`ов томам отличается от winPE 10, поэтому ссылки нужно делать делать уже загрузившись в основную ОС
{
    # изворот: в функции Add-Junctions есть обращения к глобальной конфиг-переменной $volumes
    # поэтому в тексте encodedCommand нужно определить точь в точь такую же переменную, чтобы сохранить работоспособность при выполнении через батник
    $txt = Get-Content -Encoding UTF8 -Raw -Path ((Get-Module Wenix).NestedModules | Where-Object {$_.name -match 'config'}).path
    
    $bytes = [System.Text.Encoding]::Unicode.GetBytes( ($txt -ireplace 'Export-ModuleMember -Variable \*', '') + (Get-Command Add-Junctions).Definition )
    
    $encodedCommand = [Convert]::ToBase64String($bytes)
    
    $volOSLetter = (Get-Partition -DiskNumber $DiskNumber | Get-Volume | Where-Object {$_.FileSystemLabel -eq $volumes['VolOS'].label}).DriveLetter
    
    $AutoRun = '{0}:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\Add-Junctions.cmd' -f $volOSLetter
    
    '@echo off' | Out-File -Encoding ascii -FilePath $AutoRun
    
    'powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -encodedCommand {0}' -f $encodedCommand | Out-File -Encoding ascii -FilePath $AutoRun -Append
    
    'echo Add-Junctions' | Out-File -Encoding ascii -FilePath $AutoRun -Append
    
    'echo %~dpnx0' | Out-File -Encoding ascii -FilePath $AutoRun -Append
    
    # 'start "" /b explorer.exe "%~dp0"' | Out-File -Encoding ascii -FilePath $AutoRun -Append
    
    'timeout /t 55' | Out-File -Encoding ascii -FilePath $AutoRun -Append
    
    'erase /f /q "%~dpnx0"' | Out-File -Encoding ascii -FilePath $AutoRun -Append
}


function Publish-PostInstallAutoRun  # алгоритм вычисления guid в 10й PE и в Windows 10 одинаковый - ссылки через UNC-пути сделанные из PE будут работать и в основной ОС
{
    try
    {
        # Get-Volume (и модуль Storage в целом) не работает в 7-ке, т.к. WMI не поддерживает нужные классы
        # поэтому, т.к. эта же функция используется в 7-ке через cmd-костыль, она реализована через Get-CimInstance
        # в кастомном 7-шном install.wim установлен 5.1 PowerShell
        
        # $guidPE = (Get-Partition -DiskNumber $DiskNumber -ErrorAction Stop | Get-Volume | Where-Object {$_.FileSystemLabel -eq $volumes['VolPE'].label}).Path
        
        $guidOS = (Get-Partition -DiskNumber $DiskNumber -ErrorAction Stop | Get-Volume | Where-Object {$_.FileSystemLabel -eq $volumes['VolOS'].label}).DriveLetter
        
        $AutoRun = '{0}:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\Add-Junctions.cmd' -f $guidOS
        
        $CommandText = @'
            $pe = (Get-CimInstance -ClassName 'Win32_Volume' | Where-Object {$_.SystemVolume -eq $true}).DeviceID  # pe

            $os = (Get-CimInstance -ClassName 'Win32_Volume' | Where-Object {$_.BootVolume -eq $true}).DeviceID    # os

            $AutoDir = '{0}ProgramData\Microsoft\Windows\Start Menu\Programs\Startup' -f $os

            $AutoRun = '{0}ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\Add-Junctions.cmd' -f $os

            if (Test-Path -Path ($os + '.IT')) { Remove-Item -Recurse -Force -Path ($os + '.IT') }

            if (Test-Path -Path ($pe + '.IT'))
            {
                Start-Process -FilePath "cmd.exe" -ArgumentList '/c','mklink', '/J', ($os + '.IT'), ($pe + '.IT')
            }
'@
        
        $Commandbytes = [System.Text.Encoding]::Unicode.GetBytes($CommandText)
            
        $CommandBase64 = [Convert]::ToBase64String($Commandbytes)
        
        
        '@echo off'                        | Out-File -Encoding ascii -FilePath $AutoRun
        'powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -encodedCommand {0}' -f $CommandBase64 | Out-File -Encoding ascii -FilePath $AutoRun -Append
        'echo Add-Junctions'               | Out-File -Encoding ascii -FilePath $AutoRun -Append
        'echo %~dpnx0'                     | Out-File -Encoding ascii -FilePath $AutoRun -Append
        # 'start "" /b explorer.exe "%~dp0"' | Out-File -Encoding ascii -FilePath $AutoRun -Append
        'bcdedit /timeout 5'               | Out-File -Encoding ascii -FilePath $AutoRun -Append
        # 'bcdedit /enum'                    | Out-File -Encoding ascii -FilePath $AutoRun -Append
        'timeout /t 55'                    | Out-File -Encoding ascii -FilePath $AutoRun -Append
        'erase /f /q "%~dpnx0"'            | Out-File -Encoding ascii -FilePath $AutoRun -Append
    }
    
    catch { $_ }
    
    
    return $res
}


function Select-TargetDisk  # функция получает инфо по дискам и в случае нескольких дисков предлагает выбрать целевой для развёртывания Wenix
{
    param ()
    
    begin
    {
        $MenuText = @(
            "Please enter disk`s N for Wenix deployment"
            "for example, type '0' or '1' and press 'Enter' key"
        )
        
        $drives = @()
        
        $SelectedDisk = $null
    }
    
    process
    {
        $drives +=  (
            Get-Disk |
            Where-Object {$_.BusType -inotmatch 'usb'} |
            Select-Object -Property `
                @{Name = 'N';           Expression = {$_.DiskNumber}},
                @{Name = 'type';        Expression = {$_.BusType}},
                @{Name = 'size';        Expression = {('{0,4:N0} GB' -f ($_.Size / 1GB))}},
                @{Name = 'name';        Expression = {$_.FriendlyName}},
                @{Name = 'tbl';         Expression = {$_.PartitionStyle}},
                @{Name = 'PartCount';   Expression = {$_.NumberOfPartitions}}
        )
        
        if ($drives.Count -ne 1)
        {
            $cycle = $true ; while ( $cycle )
            {
                $drives | Format-Table -Property * | Out-Default
                
                $MenuText | Out-Default
                
                $sel = Read-Host  # ожидаем ввода числа - номера диска
                
                try  # попытка преобразовать ввод пользователя в целое число - номер диска
                {
                    $sel = [int] $sel
                }
                catch  # one more time...
                {
                    "cannot find the DiskNumber '$sel', please try again...`n" | Out-Default
                    
                    continue
                }
                
                if ($sel -in $drives.N)
                {
                    $SelectedDisk = $drives | Where-Object {$_.N -eq $sel}
                    
                    $cycle = $false
                }
                else { continue }
            }
        } else { $SelectedDisk = $drives | Where-Object {$_.N -eq 0} }
    }
    
    end
    {
        return $SelectedDisk
    }
}
