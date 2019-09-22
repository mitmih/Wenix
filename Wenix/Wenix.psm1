function Use-Wenix  # главный поток исполнения скрипта
{
    param ([switch]$STOP = $false)
    
    begin
    {
        $Error.Clear()
        
        $WatchDogTimer = [system.diagnostics.stopwatch]::startNew()
        
        $log = [ordered]@{}
        
        $shares = @()
        
        $Sourses = @()  # единый набор источников PE и OS wim-файлов
    }
    
    process
    {
        $cycle = $true ; while ( $cycle )
        {
            $key = Show-Menu
            
            switch ( $key.key )
            {
                { $_ -in @( 'D0', 'D7', 'NumPad0', 'NumPad7' ) }  # нажали 0 или 7
                {
                    Write-Host ("  <<<     selected{0,62}" -f "`n") -BackgroundColor Yellow -ForegroundColor Black
                    
                    if ($STOP) { Write-Host ("    MODE    STOP{0,65}" -f "`n") -BackgroundColor Yellow -ForegroundColor Black }
                    
                    Write-Host ("{0,5:N1} minutes {1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'installation process launched') #_#
                    
                    $ver = if ( $_ -in @( 'D7', 'NumPad7' ) ) { '7' } else { '10' }  # 7 -> развёртывание Windows 7 install.wim, # 0 -> развёртывание Windows 10 install.wim
                    
                    $Disk0isOk = Test-Disk
                    
                    
                    #region  сетевые источники
                    
                    $NetConfig = Find-NetConfig  # объект файла сетевого конфига, должен лежать на томе в папке '<буква>:\.IT\PE\BootStrap.csv', поиск в алфавитном порядке C D E etc
                    
                    Write-Host ("{0,5:N1} minutes {1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Find-NetConfig BootStrap.csv') #_#
                    
                    
                    if ($null -ne $NetConfig)  # поиск wim-файлов в источниках из сетевого конфига ':\.IT\PE\BootStrap.csv'
                    {
                        $shares += $NetConfig | Read-NetConfig
                        
                        
                        Write-Host ("{0,5:N1} minutes {1} {2,45}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Read-NetConfig', ('IP  ' + (ipconfig | Select-String -Pattern 'ipv4').ToString().Split(':')[1].Trim()) ) #_#
                        
                        
                        $Sourses += Test-Wim -md5 -ver 'PE' -name 'boot'    -SharesList $shares
                        
                        Write-Host ("{0,5:N1} minutes {1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Test-Wim NetWork PE') #_#
                        
                        
                        $Sourses += Test-Wim -md5 -ver $ver -name 'install' -SharesList $shares
                        
                        Write-Host ("{0,5:N1} minutes {1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Test-Wim NetWork OS') #_#
                    }
                    else
                    {
                        Write-Host ("{0,5:N1} minutes {1} {2,45}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Read-NetConfig', ('IP  ' + (ipconfig | Select-String -Pattern 'ipv4').ToString().Split(':')[1].Trim()) ) #_#
                    }
                    
                    #endregion
                    
                    
                    #region локальные источники
                    
                    if ($Disk0isOk)  # источники с этого диска бесполезны, т.к. ему нужна переразбивка
                    {
                        $LettersExclude = @()  # буквы дисков, на которых ненужно искать wim-файлы
                    }
                    else
                    {
                        try
                        {
                            $LettersExclude = (Get-Partition -ErrorAction Stop -DiskNumber 0 | Where-Object {'' -ne $_.DriveLetter}).DriveLetter
                        }
                        catch
                        {
                            $LettersExclude = @()
                        }
                    }
                    
                    
                    $Sourses += Test-Wim -md5 -ver 'PE' -name 'boot' #-exclude $LettersExclude
                    
                    Write-Host ("{0,5:N1} minutes {1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Test-Wim local PE') #_#
                    
                    
                    $Sourses += Test-Wim -md5 -ver $ver -name 'install' -exclude $LettersExclude
                    
                    Write-Host ("{0,5:N1} minutes {1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Test-Wim local OS') #_#
                    
                    $Sourses = $Sourses | Sort-Object -Property `
                                @{Expression = {$_.OS};       Descending = $true},`
                                @{Expression = {$_.date2mod}; Descending = $true},`
                                @{Expression = {$_.Priority}; Descending = $false}
                    
                    #endregion
                    
                    
                    $log['exist PE source'] = $null -ne ($Sourses | Where-Object {$_.OS -eq 'PE'})
                    
                    $log['exist OS source'] = $null -ne ($Sourses | Where-Object {$_.OS -eq $ver})
                    
                    if ( $log['exist PE source'] -and $log['exist OS source'] )
                    # можно начинать установку
                    {
                        #region backup RAM-disk PE to memory
                        
                        $FTparams = @{
                            'Property' = @(
                                # 'gw' ,
                                # 'netpath'
                                # 'password'
                                # 'user'
                                
                                'PSDrive'
                                # 'FileExist'
                                # 'md5ok'
                                'FilePath'
                                
                                'OS'
                                # 'Root'
                                # 'FileName'
                                'FileSize'
                                'date2mod'
                                'Priority'
                        )}
                        
                        $Sourses | Select-Object @FTparams | Format-Table *
                        
                        
                        foreach ( $wim in ($Sourses | Where-Object {$_.OS -eq 'PE'}) )
                        {
                            $copy = Copy-WithCheck -from $wim.Root -to 'X:\.IT\PE'
                            
                            $log['backup ramdisk in memory'] = $copy
                            
                            if ( $copy )
                            {
                                if ( $NetConfig ) { Copy-Item -Force -Path $NetConfig -Destination 'X:\.IT\PE' }
                                
                                break
                            }
                        }
                        
                        if (!$log['backup ramdisk in memory']) { return }  # нет бэкапа RAM-диска - нет смысла продолжать т.к. не будет возможности хотя бы загрузиться с PE
                        
                        if ($STOP) { return }  #################################
                        
                        #endregion
                        
                        
                        #region Clear-Disk, restore RAM-disk PE from memory, renew boot menu
                        
                        Write-Host ("{0,5:N1} minutes {1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Test-Disk') #_#
                        
                        if ( $Disk0isOk )  # remove all (except .IT dir) # overwrite with the latest found win PE boot.wim
                        {
                            Get-Item -Path ('{0}:\*' -f (Get-Volume -FileSystemLabel $volumes['VolPE'].label).DriveLetter) -Exclude '.IT' -Force | Remove-Item -Force -Recurse  # очистка 'PE'-тома
                            
                            Write-Host ("{0,5:N1} minutes {1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Mount-Standart') #_#
                        }
                        else  # clear disk # make partition
                        {
                            $log['Edit-PartitionTable'] = Edit-PartitionTable
                            
                            Write-Host ("{0,5:N1} minutes {1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Edit-PartitionTable') #_#
                        }
                        
                        
                        if ( (Copy-WithCheck -from 'X:\.IT\PE' -to ('{0}:\.IT\PE' -f (Get-Volume -FileSystemLabel $volumes['VolPE'].label).DriveLetter) ) )
                        # copy PE folder back to the 'PE' volume # apply copied boot.wim to the 'PE' volume
                        {
                            $log['Install-Wim PE'] = (Install-Wim -ver 'PE')
                            
                            Write-Host ("{0,5:N1} minutes {1} = {2}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Install-Wim PE', $log['Install-Wim PE']) #_#
                        }
                        else { $log['restore RAM-disk from X:'] = $false }  # errors raised during copying - требуется внимание специалиста
                        
                        #endregion
                        
                        
                        #region apply install.wim to the 'OS' volume
                        
                        foreach ( $wim in ($Sourses | Where-Object {$_.OS -eq $ver}) )
                        {
                            $to = '{0}:\.IT\{1}' -f (Get-Volume -FileSystemLabel $volumes['VolPE'].label).DriveLetter, $ver
                            
                            $copy = Copy-WithCheck -from $wim.Root -to $to
                            
                            $log['backup ramdisk in memory'] = $copy
                            
                            if ( $copy ) { break }
                        }
                        
                        $log['Install-Wim OS'] = (Install-Wim -ver $ver <# -wim $wim.FilePath #>)
                        
                        Write-Host ("{0,5:N1} minutes {1} = {2}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Install-Wim OS', $log['Install-Wim OS']) #_#
                        
                        #endregion
                    }  # else { return }  # установка невозможна: один или оба источника wim-файлов пустые
                    
                    
                    Write-Host ("{0,5:N1} minutes {1} = {2}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage reboot', ($log.Values -notcontains $false)) -BackgroundColor Magenta -ForegroundColor Black #_#
                    
                    
                    # $log['debug'] = $false  # for debug
                    if ($log.Values -notcontains $false)
                    {
                        $cycle = $false  # прервать показ меню
                        
                        # Reset-OpticalDrive  # демонтаж iso-образа winPE виртуальной машины
                        
                        Set-NextBoot  # принудительно загрузиться в свежую ОС - ускоряет процесс установки
                        
                        # junction-ссылки на .IT
                        if ($ver -eq '10') { Add-Junctions } elseif ($ver -eq '7' ) { Add-Junctions7 }
                        
                        Write-Host ('|=> {0:-2} <=|' -f $ver)
                        
                        Start-Sleep -Seconds 13
                        
                        Restart-Computer -Force
                    }
                    else { return }  # ок -> перезагрузка, иначе - отладка
                }
                
                
                'Escape'
                {
                    Write-Host "ppress 'Y' to confirm exit"
                    
                    if (([console]::ReadKey()).key -eq 'Y') { $cycle = $false; Restart-Computer -Force }
                }
                
                
                'Backspace' { return }
                
                
                Default { break }
            }
        }
    }
    
    end {}
}


Export-ModuleMember -Function * -Variable *  # 'volumes', 'BootStrap'
