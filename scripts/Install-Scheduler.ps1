# Run in an elevated PowerShell. Creates the every-2-weeks Wednesday 3:00 AM task.
$ps = (Get-Command powershell.exe).Source
$script = Join-Path $PSScriptRoot 'Start-Maintenance.ps1'
$action = New-ScheduledTaskAction -Execute $ps -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$script`"" -WorkingDirectory $PSScriptRoot
$d = (Get-Date).Date
while ($d.DayOfWeek -ne 'Wednesday' -or $d.AddHours(3) -le (Get-Date)) { $d = $d.AddDays(1) }
Write-Host "First run: $($d.AddHours(3))   then every 14 days"
$trigger  = New-ScheduledTaskTrigger -Weekly -WeeksInterval 2 -DaysOfWeek Wednesday -At $d.AddHours(3)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -WakeToRun -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 4)
$me  = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$sec = Read-Host "Windows password for $me" -AsSecureString
$plain = (New-Object System.Net.NetworkCredential('', $sec)).Password
Register-ScheduledTask -TaskName 'iDRAC PowerNap Biweekly' -Action $action -Trigger $trigger -Settings $settings `
  -User $me -Password $plain -RunLevel Highest -Force
