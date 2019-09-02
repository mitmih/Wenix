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
                { $_ -in @( 'D0', 'D7' ) }  # нажали 0 или 7
                {
                    Write-Host ("  <<<     selected{0,62}" -f "`n") -BackgroundColor Yellow -ForegroundColor Black
                    
                    if ($STOP) { Write-Host ("    MODE    STOP{0,64}" -f "`n") -BackgroundColor Yellow -ForegroundColor Black }
                    
                    Write-Host ("{0:N0} minutes`t{1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'installation process launched') #_#
                    
                    $ver = if ( $_ -eq 'D7' ) { '7' } else { '10' }  # 7 -> развёртывание Windows 7 install.wim, # 0 -> развёртывание Windows 10 install.wim
                    
                    $Disk0isOk = Test-Disk
                    
                    
                    #region  сетевые источники
                    
                    $NetConfig = Find-NetConfig  # объект файла сетевого конфига, должен лежать на томе в папке '<буква>:\.IT\PE\BootStrap.csv', поиск в алфавитном порядке C D E etc
                    
                    Write-Host ("{0:N0} minutes`t{1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Find-NetConfig BootStrap.csv') #_#
                    
                    
                    if ($null -ne $NetConfig)  # поиск wim-файлов в источниках из сетевого конфига ':\.IT\PE\BootStrap.csv'
                    {
                        $shares += $NetConfig | Read-NetConfig
                        
                        Write-Host ("{0:N0} minutes`t{1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Read-NetConfig') #_#
                        
                        
                        $Sourses += Test-Wim -md5 -ver 'PE' -name 'boot'    -SharesList $shares
                        
                        Write-Host ("{0:N0} minutes`t{1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Test-Wim NetWork PE') #_#
                        
                        
                        $Sourses += Test-Wim -md5 -ver $ver -name 'install' -SharesList $shares
                        
                        Write-Host ("{0:N0} minutes`t{1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Test-Wim NetWork OS') #_#
                    }
                    
                    #endregion
                    
                    
                    #region локальные источники
                    
                    $LettersExclude = if ($Disk0isOk) { @() } else { (Get-Partition -DiskNumber 0 | Where-Object {'' -ne $_.DriveLetter}).DriveLetter }  # источники с этого диска бесполезны, т.к. ему нужна переразбивка
                    
                    $Sourses += Test-Wim -md5 -ver 'PE' -name 'boot' #-exclude $LettersExclude
                    
                    Write-Host ("{0:N0} minutes`t{1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Test-Wim local PE') #_#
                    
                    
                    $Sourses += Test-Wim -md5 -ver $ver -name 'install' -exclude $LettersExclude
                    
                    Write-Host ("{0:N0} minutes`t{1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Test-Wim local OS') #_#
                    
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
                            # $copy = if ($null -eq $wim.user) { Copy-WithCheck -from $wim.Root -to 'X:\.IT\PE' } else { Copy-WithCheck -from $wim.Root -to 'X:\.IT\PE' -net $wim }
                            $copy = Copy-WithCheck -from $wim.Root -to 'X:\.IT\PE'
                            
                            $log['backup ramdisk in memory'] = $copy
                            
                            if ( $copy )
                            {
                                Copy-Item -Force -Path $NetConfig -Destination 'X:\.IT\PE'
                                
                                break
                            }
                        }
                        
                        if (!$log['backup ramdisk in memory']) { return }  # нет бэкапа RAM-диска - нет смысла продолжать т.к. не будет возможности хотя бы загрузиться с PE
                        
                        if ($STOP) { return }  #################################
                        
                        #endregion
                        
                        
                        #region Clear-Disk, restore RAM-disk PE from memory, renew boot menu
                        
                        Write-Host ("{0:N0} minutes`t{1}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Test-Disk') #_#
                        
                        if ( $Disk0isOk )  # remove all (except .IT dir) # overwrite with the latest found win PE boot.wim
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
                            
                            Write-Host ("{0:N0} minutes`t{1} = {2}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Install-Wim PE', $log['Install-Wim PE']) #_#
                        }
                        else { $log['restore RAM-disk from X:'] = $false }  # errors raised during copying - требуется внимание специалиста
                        
                        #endregion
                        
                        
                        #region apply install.wim to 'OS' volume
                        
                        foreach ( $wim in ($Sourses | Where-Object {$_.OS -eq $ver}) )
                        {
                            $to = "$((Get-Volume -FileSystemLabel 'PE').DriveLetter):\.IT\$ver"
                            
                            # $copy = if ($null -eq $wim.user) { Copy-WithCheck -from $wim.Root -to $to } else { Copy-WithCheck -from $wim.Root -to $to -net $wim }
                            $copy = Copy-WithCheck -from $wim.Root -to $to
                            
                            $log['backup ramdisk in memory'] = $copy
                            
                            if ( $copy ) { break }
                        }
                        
                        $log['Install-Wim OS'] = (Install-Wim -ver $ver <# -wim $wim.FilePath #>)
                        
                        Write-Host ("{0:N0} minutes`t{1} = {2}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage Install-Wim OS', $log['Install-Wim OS']) #_#
                        
                        #endregion
                    }  # else { return }  # установка невозможна: один или оба источника wim-файлов пустые
                    
                    
                    Write-Host ("{0:N0} minutes`t{1} = {2}" -f $WatchDogTimer.Elapsed.TotalMinutes, 'stage reboot', ($log.Values -notcontains $false)) -BackgroundColor Magenta -ForegroundColor Black #_#
                    
                    Start-Sleep -Seconds 3
                    
                    # $log['debug'] = $false
                    if ($log.Values -notcontains $false)
                    {
                        $cycle = $false
                        
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
