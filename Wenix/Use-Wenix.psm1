$volumes = @(
    New-Object psobject -Property @{ letter = [char]'B' ; label =   'PE' ; size = 25 }  # Active, bootmgr + winPE RAM-disk
    New-Object psobject -Property @{ letter = [char]'O' ; label =   'OS' ; size = 75 }  # for windows
    New-Object psobject -Property @{ letter = [char]'P' ; label = 'Data' ; size = 15 }  # for data, will be resized to max
)


# $RetryCount = 2  # кол-во попыток скопировать install.wim на PE раздел с проверкой md5 после копирования


function Show-Menu
{
<#
.SYNOPSIS
    Show possible actions menu

.DESCRIPTION
    user can interact with Wenix by pressing keys
        Esc     reboot
        0      re-install Windows 10
        7      re-install Windows 7
        m       show menu
        b       break menu script
        t       type command
            far
            cmd

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
            
            "Please press specified key to select action:"
            
            "   <--     escape from menu"
            
            "   Esc     reboot"
            
            "   0       re-install Windows 10"
            
            "   7       re-install Windows 7"
            
            # "   t       type command"  # пока так и не использовал
            
            ""
        )
    }
    
    process { $MenuText | Out-Default }
    
    end { return [console]::ReadKey() }
}


function Test-Disk
{
    param ([switch]$skip = $false)
    
    begin
    {
        $CheckList = [ordered]@{}
        
        $wim_vol = Get-Volume | Where-Object {$_.FileSystemLabel -imatch 'PE'}  # том загрузки PE и восстановления
        
        if ($null -ne $wim_vol) { $wim_part = Get-Partition | Where-Object {$_.AccessPaths -contains $wim_vol.Path} }
    }
    
    process
    {
        foreach ($v in $volumes)
        {
            $CheckList[$v.label] = (Get-Partition -DiskNumber $wim_part.DiskNumber <# -PartitionNumber ($volumes.IndexOf($v) + 1) #> -ErrorAction Stop | Get-Volume).FileSystemLabel -icontains $v.label
        }
        
        
        $CheckList['partition count']= (Get-Partition -DiskNumber $wim_part.DiskNumber).Length -eq $volumes.Count
        
        $CheckList['partition table']= (Get-Disk -Number $wim_part.DiskNumber).PartitionStyle -match 'MBR'
    }
    
    end
    {
        if ($CheckList.Values -contains $true)
        {
            Write-Host ("    disk {0} OK     checks {2,52} {1}:" -f $wim_part.DiskNumber, $wim_vol.DriveLetter, $wim_vol.FileSystemLabel) -BackgroundColor DarkGreen
            
            $CheckList.GetEnumerator() | Where-Object {$_.value -eq $true} | Out-Default
        }
        
        if ($CheckList.Values -contains $false)
        {
            Write-Host ("    disk {0} FAILED checks {2,52} {1}:" -f $wim_part.DiskNumber, $wim_vol.DriveLetter, $wim_vol.FileSystemLabel) -BackgroundColor DarkRed
            
            $CheckList.GetEnumerator() | Where-Object {$_.value -eq $false} | Out-Default
        }
        
        
        if ($skip) { return $true } else { return ( $CheckList.count -gt 0 -and $CheckList.Values -notcontains $false ) }
    }
}


function _Test-Wim
{
    [CmdletBinding()]
    
    param ( $ver, [switch] $md5 = $false)
    
    begin
    {
        $CheckList = [ordered]@{}
        
        $PE = "$((Get-Volume | Where-Object {$_.FileSystemLabel -match 'PE'}).DriveLetter):\.IT\PE"
        
        $OS = "$((Get-Volume | Where-Object {$_.FileSystemLabel -match 'PE'}).DriveLetter):\.IT\$ver"
    }
    
    process
    {
        $CheckList["exist PE    boot.wim"] = Test-Path -Path "$PE\boot.wim"
        
        $CheckList["exist OS install.wim"] = Test-Path -Path "$OS\install.wim"
        
        if ($md5)
        {
            $PEmd5calc = Get-FileHash -Path "$PE\boot.wim" -Algorithm MD5
            
            $PEmd5file = Get-Content -Path "$PE\boot.wim.md5" | Select-String -Pattern '^[a-zA-Z0-9]' 
            
            $CheckList["MD5   PE    boot.wim"] = $PEmd5file -imatch $PEmd5calc.Hash
            
            
            $OSmd5calc = Get-FileHash -Path "$OS\install.wim" -Algorithm MD5
            
            $OSmd5file = Get-Content -Path "$OS\install.wim.md5" | Select-String -Pattern '^[a-zA-Z0-9]' 
            
            $CheckList["MD5   OS install.wim"] = $OSmd5file -imatch $OSmd5calc.Hash
        }
    }
    
    end
    {
        if ($CheckList.Values -contains $true)
        {
            Write-Host '    files checks OK                 ' -BackgroundColor DarkGreen
            $CheckList.GetEnumerator() | Where-Object {$_.value -eq $true} | Out-Default
        }
        
        if ($CheckList.Values -contains $false)
        {
            Write-Host '    files checks FAILED             ' -BackgroundColor DarkRed
            $CheckList.GetEnumerator() | Where-Object {$_.value -eq $false} | Out-Default
        }
        
        if ($CheckList.count -gt 0)
        {
            return ($CheckList.Values -notcontains $false)
        }
        else
        {
            return $false
        }
    }
}


function Edit-PartitionTable
{
    param ()
    
    begin
    {
        $res = $false
        
        $wim_vol = Get-Volume | Where-Object {$_.FileSystemLabel -match 'wim'}  # том с wim файлами
        
        if ($null -ne $wim_vol) { $wim_part = Get-Partition | Where-Object {$_.AccessPaths -contains $wim_vol.Path} }
    }
    
    process
    {
        try
        {
            if ($null -ne $wim_part)
            {
                Remove-Partition -DiskNumber $wim_part.DiskNumber -PartitionNumber (1..($wim_part.PartitionNumber - 1)) -confirm:$false -ErrorAction Stop
                
                New-Partition -DiskNumber $wim_part.DiskNumber -DriveLetter ([Char]'B') -Size  2GB -IsActive -ErrorAction Stop | Format-Volume -FileSystem 'NTFS' -NewFileSystemLabel "BOOT" -ErrorAction Stop
                
                New-Partition -DiskNumber $wim_part.DiskNumber -DriveLetter ([Char]'O') -Size 78GB           -ErrorAction Stop | Format-Volume -FileSystem 'NTFS' -NewFileSystemLabel "OS"   -ErrorAction Stop
                
                New-Partition -DiskNumber $wim_part.DiskNumber -DriveLetter ([Char]'P') -Size 17GB           -ErrorAction Stop | Format-Volume -FileSystem 'NTFS' -NewFileSystemLabel "PE"   -ErrorAction Stop
                
                # Resize-Partition -DiskNumber $wim_part.DiskNumber -PartitionNumber 3 -Size (Get-PartitionSupportedSize -DiskNumber $wim_part.DiskNumber -PartitionNumber 3).SizeMax  # -ErrorAction Stop  # выдаёт ошибку 'The partition is already the requested size.'
                
                $res = $true
            }
        }
        
        catch { $res = $false }
    }
    
    end { return $res }
}


function Install-Wim
{
    param ($vol, $ver, [switch]$PE = $false)
    
    begin
    {
        $res = $false
        
        $wim_vol = Get-Volume | Where-Object {$_.FileSystemLabel -match $vol}
        
        $ITfolder = $wim_vol.DriveLetter + ':\.IT'
        
        if (Test-Path $ITfolder)
        {
            $wimsOS = Get-ChildItem -Filter 'install.wim' -Path "$ITfolder\$ver"
            
            $wimsPE = Get-ChildItem -Filter 'boot.wim'    -Path "$ITfolder\PE"
        }
    }
    
    process
    {
        try
        {
            if ($PE)
            {
                Expand-WindowsImage -ImagePath $wimsPE.FullName -ApplyPath "P:\" -Index 1 -ErrorAction Stop
                
                Start-Process -Wait -FilePath "$env:windir\System32\BCDboot.exe" -ArgumentList "P:\Windows", "/s B:", "/f ALL"
                
                
                Copy-Item -Path ($ITfolder + '\PE') -Destination "P:\.IT\PE" -Recurse
                
                
                # make RAM Disk object
                bcdedit /create '{ramdiskoptions}' /d 'Windows PE, RAM DISK BOOT'
                bcdedit /set    '{ramdiskoptions}' ramdisksdidevice 'partition=P:'
                bcdedit /set    '{ramdiskoptions}' ramdisksdipath '\.IT\PE\boot.sdi'
                (bcdedit /create /d "Windows PE, RAM DISK LOADER" /application osloader) -match '\{.*\}'  # "The entry '{e1679017-bc5a-11e9-89cf-a91b7c7227b0}' was successfully created."
                $guid = $Matches[0]
                
                # make OS loader object
                bcdedit /set $guid   device 'ramdisk=[P:]\.IT\PE\boot.wim,{ramdiskoptions}'
                bcdedit /set $guid osdevice 'ramdisk=[P:]\.IT\PE\boot.wim,{ramdiskoptions}'
                bcdedit /set $guid path '\Windows\System32\Boot\winload.exe'
                bcdedit /set $guid systemroot '\Windows'
                bcdedit /set $guid winpe yes
                bcdedit /set $guid detecthal yes
                
                bcdedit /displayorder $guid /addfirst  # add the new boot entry to the boot menu
            }
            
            else
            {
                Format-Volume -FileSystemLabel 'OS' -NewFileSystemLabel 'OS' -ErrorAction Stop  # из-за ошибки "Access denied" при установке 10ки на 10ку
                
                Expand-WindowsImage -ImagePath $wimsOS.FullName -ApplyPath "O:\" -Index 1 -ErrorAction Stop
                
                bcdedit /delete '{default}' /cleanup  # remove default entry (boot PE from HD or old OS), leave only RAMDisk`s entry
                
                Start-Process -Wait -FilePath "$env:windir\System32\BCDboot.exe" -ArgumentList "O:\Windows"
                
                # bcdedit /timeout 5
            }
            
            $res = $true
        }
        
        catch { $res = $false }
    }
    
    end {return $res}
}


function Complete-PEPartition
{
    param ()
    
    begin
    {
        $res = $false
        
        $wim_vol = Get-Volume | Where-Object {$_.FileSystemLabel -match 'wim'}
        
        $ITfolder = $wim_vol.DriveLetter + ':\.IT'
    }
    
    process
    {
        try
        {
            Copy-Item -Path ($ITfolder + "\10") -Destination "P:\.IT\10" -Recurse -ErrorAction Stop
            
            Copy-Item -Path ($ITfolder + '\7' ) -Destination "P:\.IT\7"  -Recurse -ErrorAction Stop
            
            Remove-Partition -DiskNumber 0 -PartitionNumber 4 -Confirm:$false -ErrorAction Stop
            
            Remove-Partition -DiskNumber 0 -PartitionNumber 0 -Confirm:$false -ErrorAction Stop
            
            Resize-Partition -DiskNumber 0 -PartitionNumber 3 -Size (Get-PartitionSupportedSize -DiskNumber 0 -PartitionNumber 3).SizeMax -Confirm:$false
            
            $res = $true
        }
        
        catch { $res = $false }
    }
    
    end {return $res}
}


function Mount-Standart
{
    param ()
    
    begin { $res = $false }
    
    process
    {
        try
        {
            Get-Partition -DiskNumber 0 -PartitionNumber 1 -ErrorAction Stop | Set-Partition -NewDriveLetter B -ErrorAction Stop
            
            Get-Partition -DiskNumber 0 -PartitionNumber 2 -ErrorAction Stop | Set-Partition -NewDriveLetter O -ErrorAction Stop
            
            Get-Partition -DiskNumber 0 -PartitionNumber 3 -ErrorAction Stop | Set-Partition -NewDriveLetter P -ErrorAction Stop
            
            $res = $true
        }
        
        catch { $res = $false }
    }
    
    end { return $res }
}


function Find-NetConfig
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
{
<#
# функция читает найденный конфиг со списком сетевых папок
# по дефолт-шлюзу фильтрует список
# проверяет доступность и добавляет в список рабочих
#>
    param ($file)
    
    
    begin
    {
        $shares = @()  # список сетевых папок, отфильтрованный по назначенным шлюзам
        
        $valid = @()  # список рабочих сетевых шар
        
        $GWs = @()  # список ip-адресов шлюзов, 
        
        # Start-Process -FilePath 'wpeutil' -ArgumentList 'WaitForNetwork' -Wait  # ожидание инициализации сети
        
        foreach ($item in (ipconfig | Select-String -Pattern 'ipv4' -Context 0,2))
        {
            if (($item.Context.PostContext[1].Split(':')[1].Trim()).Length -gt 0) { $GWs += $item.Context.PostContext[1].Split(':')[1].Trim() }
        }
    }
    
    process
    {
        try
        {
            foreach ($gw in $GWs) { $shares += Import-Csv -Path $file -ErrorAction Stop | Where-Object { $_.gw -match $gw} }
            
            foreach ($s in $shares)
            {
                if (Test-Connection -Quiet -Count 3 -ComputerName $s.netpath.Split('\')[2])
                {
                    $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $s.user, (ConvertTo-SecureString $s.password -AsPlainText -Force)
                    
                    $drive = New-PSDrive -NAME T -PSProvider FileSystem -Root $s.netpath -Credential $cred -ErrorAction Stop
                    
                    if ([System.IO.Directory]::Exists($s.netpath)) { $valid += $s }
                    
                    $drive | Remove-PSDrive
                }
            }
        }
        
        catch {}
    }
    
    end { return $valid }
}


function Test-Wim
{
    [CmdletBinding()]
    
    param (
        $SharesList = $null,  # список сетевых папок либо $null (для проверки локальных файлы)
        
        $ver,  # 7 / 10 / PE
        
        $name, # boot / install
        
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
            
            foreach ($lv in (Get-Volume | Where-Object {$null -ne $_.DriveLetter}))
            # локальная коллекция
            {
                $places += (New-Object psobject -Property @{
                        "gw"        = $null
                        'netpath'   = ($lv.DriveLetter + ':')
                        "user"      = $null
                        "password"  = $null
                    })
            }
        }
        else
        {
            $places = $SharesList  # сетевая коллекция
        }
        
        
        foreach ($s in $places)  # цикл проверок коллекции
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
            
            
            if ($CheckListWim.Values -contains $true)  # вывод в консоль успешных проверок
            {
                Write-Host ("    OK          {0,-64}" -f $v.FilePath) -BackgroundColor DarkGreen
                
                $CheckListWim.GetEnumerator() | Where-Object {$_.value -eq $true} | Out-Default
            }
            
            # if ($CheckListWim.Values -contains $false)  # вывод проваленных проверок
            # {
            #     Write-Host ("    FAIL        {0,-64}" -f $v.FilePath) -BackgroundColor DarkRed
                
            #     $CheckListWim.GetEnumerator() | Where-Object {$_.value -eq $false} | Out-Default
            # }
            
            
            $valid += $v | Where-Object {$_.FileExist -eq $true -and $_.md5ok -eq $true}  # список проверенных источников файлов
            
            
            if ( !$local -and ($drive | Get-PSDrive) ) { $drive | Remove-PSDrive }  # отключение сетевого диска
        }
    }
    
    end { return $valid }
}


function Copy-WithCheck  # копирует из папки в папку с проверкой md5
{
    param (
        $from,
        $to,
        $retry = 2
    )
    
    begin
    {
        $res = @()
        
        if( !(Test-Path -Path $to) ) { New-Item -ItemType Directory -Path $to }
        
        $filesFrom = Get-ChildItem -Recurse -Path $from | Get-FileHash -Algorithm MD5
    }
    
    process
    {
        try
        {
            for ($i = 0; $i -lt $retry; $i++)  # множественные попытки копирования
            {
                foreach ($file in $filesFrom)
                {
                    $name = $file[0].Path.Split('\')[-1]
                    
                    Copy-Item -Path $file.Path -Destination "$to\$name"
                    
                    $res += (Get-FileHash -Algorithm MD5 -Path "$to\$name").Hash -eq $file.Hash
                }
                
                if ($res -notcontains $false) { break }  # копирование было успешным
            }
        }
        
        catch { $res += $false }
        
        $res = $res -notcontains $false

        Write-Host ( '{4} copy from {0,10} to {1,10} was {2,-10} {3,24}' -f $from, $to, $res, '', $(if ($res) {'OK'} else {'FAIL'}) ) -BackgroundColor $(if ($res) {'DarkGreen'} else {'DarkRed'})
    }
    
    # end { return ($res.count -gt 0 -and $res -notcontains $false) }
    end { return $res }
}


function f2
{
    param ()
    begin {}
    process {}
    end {}
}


function Use-Wenix
{
    param ()
    
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
        $cycle = $true ; while ($cycle)
        {
            $key = Show-Menu
            
            switch ($key.key)
            {
                {$_ -in @('D0', 'D7')}  # нажали 0 или 7
                {
                    "  <--     selected`n" | Out-Default
                    
                    Write-Host ("{0:N0} minutes`t{1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'installation process launched') #_#
                    
                    $ver = if ($_ -eq 'D7') { '7' } else { '10' }  # на выбор Windows 7 / 10
                    
                    
                    # $CheckDisk = Test-Disk -skip  # -skip для дебага
                    
                    Write-Host ("{0:N0} minutes`t{1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Test-Disk') #_#
                    
                    
                    #region локальные источники
                    
                    $PEsourses += Test-Wim -md5 -ver 'PE' -name 'boot'
                    
                    Write-Host ("{0:N0} minutes`t{1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Test-Wim local PE') #_#
                    
                    
                    $OSsourses += Test-Wim -md5 -ver $ver -name 'install'
                    
                    Write-Host ("{0:N0} minutes`t{1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Test-Wim local OS') #_#
                    
                    #endregion
                    
                    
                    #region  сетевые источники
                    
                    $file = Find-NetConfig  # сетевой конфиг, должен лежать на томе ':\.IT\PE\BootStrap.csv', поиск в алфавитном порядке C: D: etc
                    
                    Write-Host ("{0:N0} minutes`t{1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Find-NetConfig BootStrap.csv') #_#
                    
                    
                    if ($null -ne $file)  # поиск wim-файлов в источниках из сетевого конфига ':\.IT\PE\BootStrap.csv'
                    {
                        $shares += Read-NetConfig -file $file
                        
                        Write-Host ("{0:N0} minutes`t{1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Read-NetConfig') #_#
                        
                        
                        $PEsourses += Test-Wim -md5 -ver 'PE' -name 'boot'    -SharesList $shares
                        
                        Write-Host ("{0:N0} minutes`t{1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Test-Wim NetWork PE') #_#
                        
                        
                        $OSsourses += Test-Wim -md5 -ver $ver -name 'install' -SharesList $shares
                        
                        Write-Host ("{0:N0} minutes`t{1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Test-Wim NetWork OS') #_#
                    }
                    
                    #endregion
                    
                    
                    if ( !($OSsourses.count -gt 0 <# -and $PEsourses.count -gt 0 #>) )
                    # отбой: один или оба источника пустые, установка не будет завершена
                    {
                        $log['empty source PE'] = $OSsourses.count -eq 0
                        
                        $log['empty source OS'] = $PEsourses.count -eq 0
                    }
                    else
                    # можно начинать установку
                    {
                        $PEsourses = $PEsourses | Sort-Object -Property @{Expression = {$_.date2mod}; Descending = $true}, 'Priority'
                        
                        $OSsourses = $OSsourses | Sort-Object -Property @{Expression = {$_.date2mod}; Descending = $true}, 'Priority'
                        
                        $PEsourses, "`n", $OSsourses | Format-Table *
                        
                        foreach ($PEwim in $PEsourses)
                        {
                            if ( (Copy-WithCheck -from $PEwim.Root -to 'X:\.IT\PE') ) { break }
                        }
                        
                        
                        
                        
                        
                        
                        
                        # 
                    }
                    
                    
                    $log['debug'] = $false
                    if ($log.Values -notcontains $false) { <# Restart-Computer -Force #> } else { return }  # если все ок - перезагрузка, иначе - выход для отладки и ручных манипуляций
                }
                
                'Escape'
                {
                    Write-Host "ppress 'Y' to confirm exit"
                    
                    if (([console]::ReadKey()).key -eq 'Y') { Restart-Computer -Force }
                }
                
                'Backspace' { return }
                
                <# 'T'
                {
                    $cmd = Read-Host -Prompt "`ntype command"
                    
                    if ($cmd -eq 'far') { Start-Process -FilePath "$env:SystemDrive\Far\Far.exe" }
                    
                    if ($cmd -eq 'cmd') { Start-Process -FilePath "$env:windir\System32\cmd.exe" -ArgumentList '/k' }
                    
                    break
                } #>
                
                Default { break }
            }
        }
    }
    
    end {}
}
