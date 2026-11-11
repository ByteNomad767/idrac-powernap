# Powers on the Server, gives the server its work window, then guarantees power-off.
. "$PSScriptRoot\Common.ps1"
$ErrorActionPreference = 'Continue'
$cfg = Get-Config
Write-Log '=== Maintenance run started ==='

# 1. Don't touch a server that is already on (e.g. you're using it)
$state = 'unknown'
for ($i = 0; $i -lt 3 -and $state -eq 'unknown'; $i++) { $state = Get-PowerState; if ($state -eq 'unknown') { Start-Sleep 20 } }
if ($state -eq 'on')      { Write-Log 'Server already ON - skipping this cycle, will NOT shut it down.'; exit 0 }
if ($state -eq 'unknown') { Send-Alert 'Server: cannot read power state from iDRAC. Run skipped.'; exit 1 }

function Stop-Server {
    $s = $cfg.shutdown
    for ($a = 1; $a -le $s.gracefulAttempts; $a++) {
        Write-Log "Graceful shutdown attempt $a via SSH"
        $null = Invoke-Ssh 'shutdown -h now'
        if (Wait-PowerState 'off' ($s.waitMinutesPerAttempt * 60)) { return $true }
        Write-Log 'Still ON after wait.' 'WARN'
    }
    if ($s.softIpmiFallback) {
        Write-Log 'Trying ACPI soft shutdown via iDRAC' 'WARN'
        $null = Invoke-Ipmi chassis power soft
        if (Wait-PowerState 'off' 600) { return $true }
    }
    if ($s.hardPowerOffFallback) {
        Write-Log 'Forcing hard power off via iDRAC' 'WARN'
        $null = Invoke-Ipmi chassis power off
        if (Wait-PowerState 'off' 180) { return $true }
    }
    return $false
}

# 2. Power on with retries, verified independently
$on = $false
for ($i = 1; $i -le $cfg.powerOn.maxAttempts -and -not $on; $i++) {
    Write-Log "Power-on attempt $i of $($cfg.powerOn.maxAttempts)"
    $r = Invoke-Ipmi chassis power on
    Write-Log "ipmitool: $($r.Output)"
    $on = Wait-PowerState 'on' $cfg.powerOn.verifySeconds
    if (-not $on) { Start-Sleep 30 }
}
if (-not $on) { Send-Alert 'Server FAILED to power on after all attempts.'; exit 1 }
Write-Log 'iDRAC reports power ON'

# 3. Wait for Proxmox (one power-cycle retry if it never comes up)
$up = Wait-ProxmoxSsh $cfg.boot.sshTimeoutMinutes
if (-not $up -and $cfg.boot.allowOnePowerCycle) {
    Write-Log 'Proxmox unreachable - power cycling once' 'WARN'
    $null = Invoke-Ipmi chassis power cycle
    Start-Sleep 60
    $up = Wait-ProxmoxSsh $cfg.boot.sshTimeoutMinutes
}
if (-not $up) {
    Send-Alert 'Server powered on but Proxmox SSH never came up. Shutting it down.'
    if (Stop-Server) { Write-Log 'Server is OFF.' } else { Send-Alert 'Server STILL ON after all shutdown attempts!' }
    exit 1
}
Write-Log 'Proxmox is reachable'

# 4. Check / start the VM that does the work (optional)
$vm = $cfg.proxmox.guestVmId
if ($vm) {
    $st = (Invoke-Ssh "qm status $vm").Output
    Write-Log "VM $vm : $st"
    if ($st -notmatch 'running') { Write-Log 'Starting VM'; $null = Invoke-Ssh "qm start $vm" }
}

# 5. Sync window (starts once Proxmox is up)
Write-Log "Syncing for $($cfg.runtimeMinutes) minutes"
Start-Sleep -Seconds ($cfg.runtimeMinutes * 60)

# 6. Shut down and verify the hardware is really off
Write-Log 'Window finished - shutting down'
if (Stop-Server) { Write-Log '=== Server confirmed OFF. Run complete. ===' ; exit 0 }
Send-Alert 'Server STILL ON after all shutdown attempts - check it manually!'
exit 2
