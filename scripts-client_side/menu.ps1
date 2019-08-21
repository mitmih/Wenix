Clear-Host

$MenuText=@"
Please press specified key to select action:

    Esc     reboot
    Enter   re-install Windows 10
    m       show menu
    b       break menu script

"@

$MenuText


$cycle = $true
while ($cycle)
{
    # $key = Read-Host -Prompt "press any key..."
    $key = [console]::ReadKey()
    
    switch ($key.key)
    {
        'Enter'     { Write-Host "enter, операционная система будет переустановлена" ; break }
        
        'Escape'    { Write-Host "EEscape, компьютер будет перезагружен" ; break }
        
        # 'm' { Clear-Host ; $MenuText }
        
        'B' { $cycle = $false ; break }
        
        # {$_ -notin 'Enter', 'Escape', 'm', 'b' } { continue }
        
        Default { Clear-Host ; $MenuText ; break }
    }
    
    
    
    # if ($key.key -eq 'Enter')
    # {
    #     Write-Host "enter, операционная система будет переустановлена"
    # }
    
    # if ($key.key -eq 'Escape')
    # {
    #     Write-Host "  Escape, компьютер будет перезагружен"
    # }
    
    # if ($key.key -eq 'm')
    # {
    #     Clear-Host
    #     Write-Host $MenuText
    # }
    
    # if ($key.key -eq 'b')
    # {
    #     break
    # }
}
