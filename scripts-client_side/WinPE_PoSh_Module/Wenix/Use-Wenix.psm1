function Show-Menu {
<#
.SYNOPSIS
    Show possible actions menu

.DESCRIPTION
    user can interact with Wenix by pressing keys
        Esc     reboot
        Enter   re-install Windows 10
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
    
[CmdletBinding()]  # SupportsShouldProcess)]
    param ()
    
    begin
    {
        $MenuText = @(
            ""
            
            "Please press specified key to select action:"
            
            "Esc     reboot"
            
            "Enter   re-install Windows 10"
            
            "m       show menu"
            
            "b       break menu script"
            
            "t       type command"
            
            ""
        )
    }
    
    process { $MenuText | Out-Default }
    
    end { return [console]::ReadKey() }
}


function Test-Disk {
    param ()
    
    begin { $CheckList = @() }
    
    process
    {
        $CheckList += (Get-Partition -DiskNumber 0 -PartitionNumber 1 | Get-Volume).FileSystemLabel -match '_BOOT'
        
        $CheckList += (Get-Partition -DiskNumber 0 -PartitionNumber 2 | Get-Volume).FileSystemLabel -match '_OS'
        
        $CheckList += (Get-Partition -DiskNumber 0 -PartitionNumber 3 | Get-Volume).FileSystemLabel -match '_PE'
        
        $CheckList += (Get-Partition -DiskNumber 0).Length -ge 3
        
        $CheckList += $null -ne (BCDEdit /enum | Select-String -Pattern "^device.*ramdisk=.*.IT.PE.boot.wim")
        
        $CheckList += Test-Path -Path "$((Get-Volume | Where-Object {$_.FileSystemLabel -match '_PE'}).DriveLetter):\.IT\PE\boot.wim"
    }
    
    end
    {
        return ($CheckList -notcontains $false)
    }
}


function Test-BootMenu {
    param ()
    
    begin { $CheckList = @() }
    
    process
    {
        # device                  ramdisk=[D:]\.IT\PE\boot.wim,{ramdiskoptions}
        $bcd = $null -ne (BCDEdit /enum | Select-String -Pattern "^device.*ramdisk=.*.IT.PE.boot.wim")
        
        
        # $CheckList += ((Get-Partition -DiskNumber 0 -PartitionNumber 1 | Get-Volume).FileSystemLabel -eq '1_BOOT')
        
    }
    
    end
    {
        return ($CheckList -notcontains $false)
    }
}





function Use-Wenix {
    [CmdletBinding()]  # SupportsShouldProcess)]
    param ()
    
    begin {}
    
    process
    {
        $cycle = $true ; while ($cycle)
        {
            $key = Show-Menu
            
            switch ($key.key)
            {
                'Enter'     {
                    Write-Host "Enter, installation process launched"
                    
                    $cycle = $false
                    
                    # test-disk
                    
                    
                    
                    
                    
                    break
                }
                
                'Escape'    {
                    Write-Host "cconfirm restart - press 'y'"
                    
                    if (([console]::ReadKey()).key -eq 'Y')
                    {
                        $cycle = $false
                        
                        Restart-Computer
                    }
                    
                    break
                }
                
                'B'         {
                    $cycle = $false
                    
                    break
                }
                
                'T'         {
                    $cmd = Read-Host -Prompt "`ntype command"
                    
                    if ($cmd -eq 'far') { Start-Process -FilePath "$env:SystemDrive\Far\Far.exe" }
                    
                    if ($cmd -eq 'cmd') { Start-Process -FilePath "$env:windir\System32\cmd.exe" -ArgumentList '/k' }
                    
                    break
                }
                
                Default     { <# Clear-Host ; #> break }
            }
        }
    }
    
    end {}
}
