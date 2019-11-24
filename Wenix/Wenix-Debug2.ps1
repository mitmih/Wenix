$path = 'C:\.mdt\.IT\7\install.wim'

$algo = 'SHA1'

$count = 0

$cmd = {
    param ($path, $algo)
    Get-FileHash -Path $path -Algorithm $algo
}


$job = Start-Job -Name 'check md5' -ScriptBlock $cmd -ArgumentList $path, $algo

while ($job.State -ne 'Completed')
{
    Write-Progress -Activity $path -PercentComplete ($count % 100) -Status $algo
    
    Start-Sleep -Milliseconds 331
    
    $count += (Get-Random -Minimum 0 -Maximum 17) % 100
}

$hash = $job | Wait-Job | Receive-Job

$job | Remove-Job -Force

$hash.Hash



<# 'MACTripleDES', 'MD5', 'RIPEMD160', 'SHA1', 'SHA256', 'SHA384', 'SHA512'

7 install.wim

Name         Key                Value
----         ---                -----
MACTripleDES MACTripleDES 218,8642759
RIPEMD160    RIPEMD160     46,6866141
SHA256       SHA256        32,9847774
SHA384       SHA384        21,7708888
SHA512       SHA512        21,7365543
MD5          MD5           18,0964919
SHA1         SHA1          16,5415910


pe boot.wim

Name         Key               Value
----         ---               -----
MACTripleDES MACTripleDES 12,4528882
RIPEMD160    RIPEMD160     2,9725532
SHA256       SHA256        2,1737768
SHA512       SHA512        1,5172101
SHA384       SHA384        1,5064515
MD5          MD5           1,3230142
SHA1         SHA1          1,3006401

#>