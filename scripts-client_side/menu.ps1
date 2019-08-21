# Clear-Host

$MenuText=@"
Please press specified key to select action:

    Esc     reboot
    Enter   re-install Windows 10
    m       show menu
    b       break menu script

"@

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
        
        Default     { Clear-Host ; $MenuText ; break }
    }
}
