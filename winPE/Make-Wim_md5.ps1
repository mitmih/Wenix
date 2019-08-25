Set-Location "$($MyInvocation.MyCommand.Definition | Split-Path -Parent)"

$HashSum = Get-FileHash -Algorithm MD5 -Path ".\.pe_work_dir\amd64\media\sources\boot.wim"

$HashSum.Hash + ' *boot.wim' | Out-File -Encoding ascii -FilePath ".\.pe_work_dir\amd64\media\sources\boot.wim.md5"