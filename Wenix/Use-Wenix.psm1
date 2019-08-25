function Show-Menu {
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


function Test-Disk {
    param ()
    
    begin
    {
        $CheckList = [ordered]@{}
        
        $wim_vol = Get-Volume | Where-Object {$_.FileSystemLabel -match 'wim'}  # том с wim файлами
        
        if ($null -eq $wim_vol) { $wim_vol = Get-Volume | Where-Object {$_.FileSystemLabel -eq '3_PE'} }  # том с wim файлами
        
        if ($null -ne $wim_vol) { $wim_part = Get-Partition | Where-Object {$_.AccessPaths -contains $wim_vol.Path} }
    }
    
    process
    {
        $CheckList['1_BOOT'] = (Get-Partition -DiskNumber $wim_part.DiskNumber -PartitionNumber 1 -ErrorAction Stop | Get-Volume).FileSystemLabel -match '1_BOOT'
        
        $CheckList['2_OS']   = (Get-Partition -DiskNumber $wim_part.DiskNumber -PartitionNumber 2 -ErrorAction Stop | Get-Volume).FileSystemLabel -match '2_OS'
        
        $CheckList['3_PE']   = (Get-Partition -DiskNumber $wim_part.DiskNumber -PartitionNumber 3 -ErrorAction Stop | Get-Volume).FileSystemLabel -match '3_PE'
        
        $CheckList['partition count']= (Get-Partition -DiskNumber $wim_part.DiskNumber).Length -eq 3
        
        $CheckList['partition table']= (Get-Disk -Number 0).PartitionStyle -match 'MBR'
        
        # $CheckList['2nd boot menu entry'] = $null -ne (BCDEdit /enum | Select-String -Pattern "^device.*ramdisk=.*.IT.PE.boot.wim")
    }
    
    end
    {
        if ($CheckList.Values -contains $true)
        {
            Write-Host '    disk checks OK                  ' -BackgroundColor DarkGreen
            $CheckList.GetEnumerator() | Where-Object {$_.value -eq $true} | Out-Default
        }
        
        if ($CheckList.Values -contains $false)
        {
            Write-Host '    disk checks FAILED              ' -BackgroundColor DarkRed
            $CheckList.GetEnumerator() | Where-Object {$_.value -eq $false} | Out-Default
        }
        
        if ($CheckList.count -gt 0) { return ($CheckList.Values -notcontains $false) } # else { return $false }
    }
}


function Test-Wim {
    
    [CmdletBinding()]
    
    param ( $label, $ver, [switch] $md5 = $false)
    
    begin
    {
        $CheckList = [ordered]@{}
        
        $PE = "$((Get-Volume | Where-Object {$_.FileSystemLabel -match "$label"}).DriveLetter):\.IT\PE"
        
        $OS = "$((Get-Volume | Where-Object {$_.FileSystemLabel -match "$label"}).DriveLetter):\.IT\$ver"
    }
    
    process
    {
        $CheckList["exist PE    boot.wim"] = Test-Path -Path "$PE\boot.wim"
        
        $CheckList["exist OS install.wim"] = Test-Path -Path "$OS\install.wim"
        
        if ($md5)
        {
            $PEmd5calc = Get-FileHash -Path "$PE\boot.wim" -Algorithm MD5
            
            $PEmd5real = Get-Content -Path "$PE\boot.wim.md5" | Select-String -Pattern '^[a-zA-Z0-9]' 
            
            $CheckList["MD5   PE    boot.wim"] = $PEmd5real -imatch $PEmd5calc.Hash
            
            
            $OSmd5calc = Get-FileHash -Path "$OS\install.wim" -Algorithm MD5
            
            $OSmd5real = Get-Content -Path "$OS\install.wim.md5" | Select-String -Pattern '^[a-zA-Z0-9]' 
            
            $CheckList["MD5   OS install.wim"] = $OSmd5real -imatch $OSmd5calc.Hash
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
                
                New-Partition -DiskNumber $wim_part.DiskNumber -DriveLetter ([Char]'B') -Size  2GB -IsActive -ErrorAction Stop | Format-Volume -FileSystem 'NTFS' -NewFileSystemLabel "1_BOOT" -ErrorAction Stop
                
                New-Partition -DiskNumber $wim_part.DiskNumber -DriveLetter ([Char]'O') -Size 78GB           -ErrorAction Stop | Format-Volume -FileSystem 'NTFS' -NewFileSystemLabel "2_OS"   -ErrorAction Stop
                
                New-Partition -DiskNumber $wim_part.DiskNumber -DriveLetter ([Char]'P') -Size 17GB           -ErrorAction Stop | Format-Volume -FileSystem 'NTFS' -NewFileSystemLabel "3_PE"   -ErrorAction Stop
                
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
    param ($vol, $ver, [switch]$PE=$false)
    
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
                Format-Volume -FileSystemLabel '2_OS' -NewFileSystemLabel '2_OS' -ErrorAction Stop  # из-за ошибки "Access denied" при установке 10ки на 10ку
                
                Expand-WindowsImage -ImagePath $wimsOS.FullName -ApplyPath "O:\" -Index 1 -ErrorAction Stop
                
                bcdedit /delete '{default}' /cleanup  # remove default entry (boot PE from HD or old OS), leave only RAMDisk`s entry
                
                Start-Process -Wait -FilePath "$env:windir\System32\BCDboot.exe" -ArgumentList "O:\Windows"
                
                bcdedit /timeout 5
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


function Use-Wenix {
    param ()
    
    begin { $log = [ordered]@{} }
    
    process
    {
        $cycle = $true ; while ($cycle)
        {
            $key = Show-Menu
            
            switch ($key.key)
            {
                {$_ -in @('D0', 'D7')}  # нажали 0 или 7
                {
                    $WatchDogTimer = [system.diagnostics.stopwatch]::startNew()
                    
                    Write-Host "installation process launched"
                    
                    $ver = if ($_ -eq 'D7') { '7' } else { '10' }
                    
                    $checkDisk = Test-Disk
                    
                    $checkWim = if ($checkDisk) { Test-Wim -ver $ver -label "_PE" -md5 } else { Test-Wim -ver $ver -label "wim" -md5 }
                    
                    # переделать чеки вим-файлов: может быть ситуация когда диск уже разбит, но файлов на 3_PE ещё нет и нужно перезапустить установку, т.е. при новом диске использовать вим-файлы с временного раздела (напр. произошел сбой по питанию при заливке install.wim)
                    # можно чекать wim-файлы независимо от состояния диска и использовать в первую очередь файлы с временного 'wim' тома
                    
                    Write-Host "checked`t`t`t", $WatchDogTimer.Elapsed.TotalMinutes -ForegroundColor Yellow
                    
                    
                    if ( $checkDisk -and $checkWim)
                    # диск уже размечен как надо, и wim-файлы находятся на 3-ем разделе с меткой '3_PE'
                    {
                        Write-Host "1st way: re-apply OS wim to 2_OS volume" -BackgroundColor Black
                        
                        $log['Mount-Standart'] = Mount-Standart
                        
                        Write-Host "Mount-Standart`t`t", $WatchDogTimer.Elapsed.TotalMinutes -ForegroundColor Yellow
                        
                        
                        $log['Install-Wim OS'] = Install-Wim -vol '3_PE' -ver $ver      # накатываем ОС c временного раздела ('wim' в метке тома)
                        
                        Write-Host "Install-Wim OS`t`t", $log['Install-Wim OS'], $WatchDogTimer.Elapsed.TotalMinutes -ForegroundColor Yellow
                    }
                    
                    elseif (!$checkDisk -and $checkWim)
                    # диск ещё не размечен на три раздела, а wim-файлы находятся на доп. разделе с меткой 'wim'
                    {
                        Write-Host "2nd way: remap disk, apply PE wim and OS wim, move wim-files to new 3_PE volume" -BackgroundColor Black
                        
                        
                        $log['Edit-PartitionTable'] = Edit-PartitionTable
                        
                        Write-Host "Edit-PartitionTable`t", $WatchDogTimer.Elapsed.TotalMinutes -ForegroundColor Yellow
                        
                        
                        $log['Install-Wim PE'] = Install-Wim -vol 'wim' -ver $ver -PE  # накатываем PE c временного раздела ('wim' в метке тома)
                        
                        Write-Host "Install-Wim PE`t`t", $WatchDogTimer.Elapsed.TotalMinutes -ForegroundColor Yellow
                        
                        
                        $log['Install-Wim OS'] = Install-Wim -vol 'wim' -ver $ver      # накатываем ОС c временного раздела ('wim' в метке тома)
                        
                        Write-Host "Install-Wim OS`t`t", $log['Install-Wim OS'], $WatchDogTimer.Elapsed.TotalMinutes -ForegroundColor Yellow
                        
                        
                        if ($log.Values -notcontains $false) { $log['Complete-PEPartition'] = Complete-PEPartition <# -ver $ver #> }  # завершающий этап: +wim-файлы на '3_PE' раздел, -'wim' раздел, расширение '3_PE' до max
                        
                        Write-Host "all DONE !`t`t", $WatchDogTimer.Elapsed.TotalMinutes -ForegroundColor Yellow
                    }
                    
                    else { Write-Host "3 - NOT READY" -BackgroundColor Black}
                    
                    
                    if ($log.Values -notcontains $false) { Restart-Computer -Force } else { return }  # если все ок - перезагрузка, иначе - выход для отладки и ручных манипуляций
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
