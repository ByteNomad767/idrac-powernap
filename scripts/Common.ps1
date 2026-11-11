$Script:Root = Split-Path -Parent $PSScriptRoot
function Get-Config {
    $p = Join-Path $Script:Root 'config\config.json'
    if (-not (Test-Path $p)) { throw "config\config.json not found. Copy config\config.example.json to config\config.json and edit it." }
    Get-Content $p -Raw | ConvertFrom-Json
}

function Write-Log {
    param([string]$Msg, [string]$Level = 'INFO')
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Msg
    Add-Content -Path (Join-Path $Script:Root 'logs\maintenance.log') -Value $line
    Write-Host $line
}

function Send-Alert {
    param([string]$Msg)
    Write-Log $Msg 'ALERT'
    $url = (Get-Config).notify.ntfyUrl
    if ($url) { try { Invoke-RestMethod -Uri $url -Method Post -Body $Msg -TimeoutSec 15 | Out-Null } catch { Write-Log "Notify failed: $_" 'WARN' } }
}

function Get-IpmiPath {
    $p = (Get-Config).ipmitoolPath
    if (-not [IO.Path]::IsPathRooted($p)) { $p = Join-Path $Script:Root $p }
    if (Test-Path $p) { return $p }
    $c = Get-Command ipmitool.exe -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    throw "ipmitool.exe not found. Put it in the tools folder (see tools\README.md)."
}

function Invoke-Ipmi {
    param([Parameter(ValueFromRemainingArguments)][string[]]$IpmiArgs)
    $cfg  = Get-Config
    $cred = Import-Clixml (Join-Path $Script:Root 'config\idrac.cred.xml')
    $env:IPMI_PASSWORD = $cred.GetNetworkCredential().Password
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        $out = & (Get-IpmiPath) -I lanplus -H $cfg.idrac.host -U $cred.UserName -E @IpmiArgs 2>&1 | Out-String
        [pscustomobject]@{ Code = $LASTEXITCODE; Output = $out.Trim() }
    } finally { $ErrorActionPreference = $old; Remove-Item Env:IPMI_PASSWORD -ErrorAction SilentlyContinue }
}

# returns 'on', 'off' or 'unknown'
function Get-PowerState {
    try {
        $r = Invoke-Ipmi chassis power status
        if ($r.Output -match 'is on')  { return 'on' }
        if ($r.Output -match 'is off') { return 'off' }
    } catch { Write-Log "Power status error: $_" 'WARN' }
    return 'unknown'
}

function Wait-PowerState {
    param([string]$Want, [int]$Seconds)
    $end = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $end) {
        if ((Get-PowerState) -eq $Want) { return $true }
        Start-Sleep -Seconds 10
    }
    return $false
}

function Test-Port {
    param([string]$HostName, [int]$Port, [int]$TimeoutMs = 3000)
    $c = New-Object Net.Sockets.TcpClient
    try { $a = $c.BeginConnect($HostName, $Port, $null, $null); return ($a.AsyncWaitHandle.WaitOne($TimeoutMs) -and $c.Connected) }
    catch { return $false } finally { $c.Close() }
}

function Invoke-Ssh {
    param([string]$Command)
    $cfg = Get-Config
    $key = Join-Path $Script:Root 'ssh\id_ed25519'
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        $out = & ssh.exe -i $key -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 "$($cfg.proxmox.sshUser)@$($cfg.proxmox.host)" $Command 2>&1 | Out-String
        [pscustomobject]@{ Code = $LASTEXITCODE; Output = $out.Trim() }
    } finally { $ErrorActionPreference = $old }
}

function Wait-ProxmoxSsh {
    param([int]$Minutes)
    $cfg = Get-Config
    $end = (Get-Date).AddMinutes($Minutes)
    while ((Get-Date) -lt $end) {
        if ((Test-Port $cfg.proxmox.host 22) -and ((Invoke-Ssh 'echo ok').Output -match 'ok')) { return $true }
        Start-Sleep -Seconds 15
    }
    return $false
}
