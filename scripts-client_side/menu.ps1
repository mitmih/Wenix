# Clear-Host

# $MenuText=@"

# Please press specified key to select action:
    
#     Esc     reboot
    
#     Enter   re-install Windows 10
    
#     m       show menu
    
#     b       break menu script
    
#     t       type command
    
# "@

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

$MenuText

$cycle = $true ; while ($cycle)
{
    # $key = Read-Host -Prompt "press any key..."
    $key = [console]::ReadKey()
    
    switch ($key.key)
    {
        'Enter'     { Write-Host "Enter, installation process launched" ; break }
        
        'Escape'    { Write-Host "EEscape, PC will be restarted" ; break }
        
        'B'         { $cycle = $false ; break }
        
        'T'         {
            $cmd = Read-Host -Prompt "`ntype command"
            
            if ($cmd -eq 'far') { Start-Process -FilePath "$env:SystemDrive\Far\Far.exe" }
            
            if ($cmd -eq 'cmd') { Start-Process -FilePath "$env:windir\System32\cmd.exe" -ArgumentList '/k' }
            
            break
        }
        
        Default     { Clear-Host ; $MenuText ; break }
    }
}
