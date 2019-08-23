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
            
            "Please press specified key to select action:"
            
            "   Esc    reboot"
            
            "   0      re-install Windows 10"
            
            "   7      re-install Windows 7"
            
            "   b      break menu script"
            
            "   t      type command"
            
            ""
        )
    }
    
    process { $MenuText | Out-Default }
    
    end { return [console]::ReadKey() }
}


function Test-Disk {
    param ()
    
    begin { $CheckList = [ordered]@{} }
    
    process
    {
        $CheckList['boot'] = (Get-Partition -DiskNumber 0 -PartitionNumber 1 | Get-Volume).FileSystemLabel -match '_BOOT'
        
        $CheckList['os'] = (Get-Partition -DiskNumber 0 -PartitionNumber 2 | Get-Volume).FileSystemLabel -match '_OS'
        
        $CheckList['pe'] = (Get-Partition -DiskNumber 0 -PartitionNumber 3 | Get-Volume).FileSystemLabel -match '_PE'
        
        $CheckList['partition count']= (Get-Partition -DiskNumber 0).Length -eq 3
        
        # PartitionStyle     : GPT
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
            
            $CheckList["PE boot.wim MD5"] = $PEmd5real -imatch $PEmd5calc.Hash
            
            
            $OSmd5calc = Get-FileHash -Path "$OS\install.wim" -Algorithm MD5
            
            $OSmd5real = Get-Content -Path "$OS\install.wim.md5" | Select-String -Pattern '^[a-zA-Z0-9]' 
            
            $CheckList["OS install.wim MD5"] = $OSmd5real -imatch $OSmd5calc.Hash
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
        $wim_vol = Get-Volume | Where-Object {$_.FileSystemLabel -match 'wim'}  # том с wim файлами
        
        if ($null -ne $wim_vol)
        {
            $wim_part = Get-Partition -DiskNumber 0 | Where-Object {$_.AccessPaths -contains $wim_vol.Path}
        }
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
                
                New-Partition -DiskNumber $wim_part.DiskNumber -DriveLetter ([Char]'P') -Size 13GB           -ErrorAction Stop | Format-Volume -FileSystem 'NTFS' -NewFileSystemLabel "3_PE"   -ErrorAction Stop
                
                Resize-Partition -DiskNumber 0 -PartitionNumber 3 -Size (Get-PartitionSupportedSize -DiskNumber 0 -PartitionNumber 3).SizeMax
                
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
                bcdedit /delete '{default}' /cleanup  # remove boot PE from HD entry, leave only RAMDisk`s entry
            }
            
            else
            {
                Expand-WindowsImage -ImagePath $wimsOS.FullName -ApplyPath "O:\" -Index 1 -ErrorAction Stop
                
                Start-Process -Wait -FilePath "$env:windir\System32\BCDboot.exe" -ArgumentList "O:\Windows"
            }
            
            $res = $true
        }
        
        catch { $res = $false }
    }
    
    end {return $res}
}


function Complete-PEPartition {
    param ()
    
    begin
    {
        $wim_vol = Get-Volume | Where-Object {$_.FileSystemLabel -match 'wim'}
        
        $ITfolder = $wim_vol.DriveLetter + ':\.IT'
    }
    
    process
    {
        try
        {
            Copy-Item -Path ($ITfolder + '\10') -Destination "P:\.IT\10" -Recurse -ErrorAction Stop
            
            Copy-Item -Path ($ITfolder + '\7' ) -Destination "P:\.IT\7"  -Recurse -ErrorAction Stop
            
            Remove-Partition -DiskNumber 0 -PartitionNumber 4,0 -Confirm:$false -ErrorAction Stop
            
            Resize-Partition -DiskNumber 0 -PartitionNumber 3 -Size (Get-PartitionSupportedSize -DiskNumber 0 -PartitionNumber 3).SizeMax
            
            $res = $true
        }
        
        catch { $res = $false }
    }
    
    end {return $res}
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
                    
                    $checkWim = if ($checkDisk) { Test-Wim -ver $ver -label "_PE" <# -md5 #> } else { Test-Wim -ver $ver -label "wim" <# -md5 #> }
                    
                    # переделать чеки вим-файлов: может быть ситуация когда диск уже разбит, но файлов на 3_PE ещё нет и нужно перезапустить установку, т.е. при новом диске использовать вим-файлы с временного раздела
                    
                    $WatchDogTimer.Elapsed.TotalMinutes
                    
                    
                    if ( $checkDisk -and $checkWim)
                    # диск уже размечен как надо, и wim-файлы находятся на 3-ем разделе с меткой '3_PE'
                    {Write-Host "1st way: re-apply OS wim to 2_OS volume" -BackgroundColor DarkYellow}
                    
                    elseif (!$checkDisk -and $checkWim)
                    # диск ещё не размечен на три раздела, а wim-файлы находятся на доп. разделе с меткой 'wim'
                    {
                        Write-Host "2nd way: remap disk, apply PE wim and OS wim, move wim-files to new 3_PE volume" -BackgroundColor DarkYellow
                        
                        $log['Edit-PartitionTable'] = Edit-PartitionTable
                        
                        $WatchDogTimer.Elapsed.TotalMinutes
                        
                        
                        $log['Install-Wim PE'] = Install-Wim -vol 'wim' -ver $ver -PE  # накатываем PE c временного раздела ('wim' в метке тома)
                        
                        $WatchDogTimer.Elapsed.TotalMinutes
                        
                        
                        $log['Install-Wim OS'] = Install-Wim -vol 'wim' -ver $ver      # накатываем ОС c временного раздела ('wim' в метке тома)
                        
                        $WatchDogTimer.Elapsed.TotalMinutes
                        
                        
                        if ($log.Values -notcontains $false) { $log['Complete-PEPartition'] = Complete-PEPartition }  # завершающий этап: +wim-файлы на '3_PE' раздел, -'wim' раздел, расширение '3_PE' до max
                        
                        Get-Partition -DiskNumber 0
                        
                        $WatchDogTimer.Elapsed.TotalMinutes
                    }
                    
                    else
                    {Write-Host "3 - NOT READY"}
                    
                    
                    if ($log.Values -notcontains $false) { exit } else { return }  # если все ок - перезагрузка, иначе - выход для отладки и ручных манипуляций
                }
                
                'Escape'
                {
                    Write-Host "ppress 'Y' to confirm exit"
                    
                    if (([console]::ReadKey()).key -eq 'Y') { exit }
                }
                
                'B' { return }
                
                'T'
                {
                    $cmd = Read-Host -Prompt "`ntype command"
                    
                    if ($cmd -eq 'far') { Start-Process -FilePath "$env:SystemDrive\Far\Far.exe" }
                    
                    if ($cmd -eq 'cmd') { Start-Process -FilePath "$env:windir\System32\cmd.exe" -ArgumentList '/k' }
                    
                    break
                }
                
                Default { break }
            }
        }
    }
    
    end {}
}
