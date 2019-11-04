param (
    [string] $path = ".\.pe_work_dir\amd64\media\sources\boot.wim"
    )

Set-Location "$($MyInvocation.MyCommand.Definition | Split-Path -Parent)"

# $HashSum = Get-FileHash -Algorithm MD5 -Path ".\.pe_work_dir\amd64\media\sources\boot.wim"

# $HashSum.Hash + ' *boot.wim' | Out-File -Encoding ascii -FilePath ".\.pe_work_dir\amd64\media\sources\boot.wim.md5"

if (Test-Path -Path $path)
{
    $HashSum = Get-FileHash -Algorithm MD5 -Path $path
    
    $HashSum.Hash + ' *' + $path.Split('\')[-1] | Out-File -Encoding ascii -FilePath ($path + ".md5")
}
