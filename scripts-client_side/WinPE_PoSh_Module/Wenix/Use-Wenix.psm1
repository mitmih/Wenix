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
    
    # [CmdletBinding()]  # SupportsShouldProcess)]
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
    # [CmdletBinding()]  # SupportsShouldProcess)]
    param ()
    
    begin { $CheckList = [ordered]@{} }
    
    process
    {
        $CheckList['boot'] = (Get-Partition -DiskNumber 0 -PartitionNumber 1 | Get-Volume).FileSystemLabel -match '_BOOT'
        
        $CheckList['os'] = (Get-Partition -DiskNumber 0 -PartitionNumber 2 | Get-Volume).FileSystemLabel -match '_OS'
        
        $CheckList['pe'] = (Get-Partition -DiskNumber 0 -PartitionNumber 3 | Get-Volume).FileSystemLabel -match '_PE'
        
        $CheckList['partition count']= (Get-Partition -DiskNumber 0).Length -ge 3
        
        $CheckList['2nd boot menu entry'] = $null -ne (BCDEdit /enum | Select-String -Pattern "^device.*ramdisk=.*.IT.PE.boot.wim")
    }
    
    end
    {
        if ($CheckList.Values -contains $true)
        {
            Write-Host '    disk checks OK                  ' -BackgroundColor Gray -ForegroundColor DarkGreen
            $CheckList.GetEnumerator() | Where-Object {$_.value -eq $true} | Out-Default
        }
        
        if ($CheckList.Values -contains $false)
        {
            Write-Host '    disk checks FAILED              ' -BackgroundColor Gray -ForegroundColor DarkRed
            $CheckList.GetEnumerator() | Where-Object {$_.value -eq $false} | Out-Default
        }
        
        return ($CheckList.Values -notcontains $false)
    }
}


function Test-Wim {
    [CmdletBinding()]  # SupportsShouldProcess)]
    param ( $label, $ver, [switch] $md5 = $false)
    
    begin
    {
        $CheckList = [ordered]@{}
        
        $PE = "$((Get-Volume | Where-Object {$_.FileSystemLabel -match "$label"}).DriveLetter):\.IT\PE"
        
        $OS = "$((Get-Volume | Where-Object {$_.FileSystemLabel -match "$label"}).DriveLetter):\.IT\$ver"
    }
    
    process
    {
        $CheckList["PE boot.wim exist"] = Test-Path -Path "$PE\boot.wim"
        
        $CheckList["OS install.wim exist"] = Test-Path -Path "$OS\install.wim"
        
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
            Write-Host '    files checks OK                 ' -BackgroundColor Gray -ForegroundColor DarkGreen
            $CheckList.GetEnumerator() | Where-Object {$_.value -eq $true} | Out-Default
        }
        
        if ($CheckList.Values -contains $false)
        {
            Write-Host '    files checks FAILED             ' -BackgroundColor Gray -ForegroundColor DarkRed
            $CheckList.GetEnumerator() | Where-Object {$_.value -eq $false} | Out-Default
        }
        
        return ($CheckList.Values -notcontains $false)
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
                    
                    $checkDisk = Test-Disk
                    $checkWim = if ($checkDisk) { Test-Wim -ver $ver -label "_PE" <# -md5 #> } else { Test-Wim -ver $ver -label "wim" <# -md5 #> }
                    
                    # $checkDisk = (Test-Disk) -or $true  # for debug both ways
                    if     ( $checkDisk -and $checkWim) {Write-Host "1 - re-apply wim"}
                    elseif (!$checkDisk -and $checkWim) {Write-Host "2 - remap disk, re-apply wim"}
                    
                    return
                }
                
                'Escape' {
                    Write-Host "ppress 'Y' to confirm exit"
                    
                    if (([console]::ReadKey()).key -eq 'Y') { exit }
                }
                
                'B' { return }
                
                'T' {
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
