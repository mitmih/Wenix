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
    
[CmdletBinding()]  # SupportsShouldProcess)]
    param ()
    
    begin
    {
        $MenuText = @(
            ""
            
            "Please press specified key to select action:"
            
            "Esc    reboot"
            
            "0      re-install Windows 10"
            
            "7      re-install Windows 7"
            
            # "m      show menu"
            
            "b      break menu script"
            
            "t      type command"
            
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
    }
    
    end
    {
        return ($CheckList -notcontains $false)
    }
}


function Test-Wim {
    param ($ver)
    
    begin { $CheckList = @() }
    
    process
    {
        $CheckList += Test-Path -Path "$((Get-Volume | Where-Object {$_.FileSystemLabel -match '_PE'}).DriveLetter):\.IT\PE\boot.wim"
        
        $CheckList += Test-Path -Path "$((Get-Volume | Where-Object {$_.FileSystemLabel -match '_PE'}).DriveLetter):\.IT\$ver\install.wim"
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
                {$_ -in @('D0', 'D7')} {
                    Write-Host "installation process launched"
                    
                    $ver = if ($_ -eq 'D7') { '7' } else { '10' }
                    $ver
                    
                    if (Test-Wim $ver)
                    {
                        $cycle = $false
                        if (Test-Disk -and Test-Wim $ver)
                        # диск разбит как надо: назначаем буковки разделам, перенакатываем раздел с виндой, удаляем старую запись и добавляем новую в BCD
                        {}
                        elseif (Test-Wim $ver)
                        # диск нужно переразбить, назначить буквы, накатить PE, прописать в BCD загрузку PE с ЖД и с рам-диска, накатить винду, добавить загрузку винды
                        {}
                    }
                    
                    
                    break
                }
                
                'Escape' {
                    Write-Host "ppress 'y' to confirm exit"
                    
                    if (([console]::ReadKey()).key -eq 'Y') { exit }
                }
                
                'B' { return }
                
                'T' {
                    $cmd = Read-Host -Prompt "`ntype command"
                    
                    if ($cmd -eq 'far') { Start-Process -FilePath "$env:SystemDrive\Far\Far.exe" }
                    
                    if ($cmd -eq 'cmd') { Start-Process -FilePath "$env:windir\System32\cmd.exe" -ArgumentList '/k' }
                    
                    break
                }
                
                Default     { Clear-Host ; break }
            }
        }
    }
    
    end {}
}
