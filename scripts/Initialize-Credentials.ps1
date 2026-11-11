# Run once, as the SAME Windows user the scheduled task will run as.
. "$PSScriptRoot\Common.ps1"
$user = Read-Host 'iDRAC username (press Enter for root)'
if (-not $user) { $user = 'root' }
$pw = Read-Host 'iDRAC password' -AsSecureString
$c = New-Object System.Management.Automation.PSCredential($user, $pw)
$c | Export-Clixml (Join-Path $Script:Root 'config\idrac.cred.xml')
Write-Host 'Saved (encrypted for this Windows user only).'