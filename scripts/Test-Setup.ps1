. "$PSScriptRoot\Common.ps1"
$cfg = Get-Config
function Check($n, $ok) { Write-Host ("{0,-28} {1}" -f $n, $(if ($ok) { 'PASS' } else { 'FAIL' })) -ForegroundColor $(if ($ok) { 'Green' } else { 'Red' }) }
$ipmiOk = $true; try { $null = Get-IpmiPath } catch { $ipmiOk = $false }
Check 'ipmitool found'        $ipmiOk
Check 'iDRAC credential file' (Test-Path (Join-Path $Script:Root 'config\idrac.cred.xml'))
$s = Get-PowerState
Check "iDRAC power status ($s)" ($s -ne 'unknown')
Check 'SSH key exists'        (Test-Path (Join-Path $Script:Root 'ssh\id_ed25519'))
if ($s -eq 'on') {
    Check 'Proxmox SSH login' ((Invoke-Ssh 'echo ok').Output -match 'ok')
    if ($cfg.proxmox.guestVmId) { Write-Host (Invoke-Ssh "qm status $($cfg.proxmox.guestVmId)").Output }
} else {
    Write-Host 'Server is off - power it on to test SSH/VM checks.'
}