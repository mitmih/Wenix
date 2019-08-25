# handling net use error messages with powershell
# https://stackoverflow.com/questions/39272345/handling-net-use-error-messages-with-powershell

# $ProcessStartInfo = new-object System.Diagnostics.ProcessStartInfo
# $ProcessStartInfo.Filename = "net.exe"
# $ProcessStartInfo.UseShellExecute = $false
# $ProcessStartInfo.Arguments = @('use', 'T:', $s.netpath, $s.password, "/user:$($s.user)")
# $ProcessStartInfo.redirectstandardError = $true
# #start process and wait for it to exit
# $proc = New-Object System.Diagnostics.Process
# $proc.StartInfo = $ProcessStartInfo
# $proc.start() | out-null
# $proc.waitforexit()
# #check the returncode
# if($proc.exitcode -ne 0)
# {
#     $err = $proc.standardError.ReadToEnd()
#     $err
# }