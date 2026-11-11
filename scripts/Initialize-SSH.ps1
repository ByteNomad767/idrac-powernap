# Creates a key and authorizes it on Proxmox (asks for the root password once).
. "$PSScriptRoot\Common.ps1"
$cfg = Get-Config
$key = Join-Path $Script:Root 'ssh\id_ed25519'
if (-not (Test-Path $key)) { & ssh-keygen.exe -t ed25519 -f $key -N '""' -C 'idrac-powernap' }
$target = "$($cfg.proxmox.sshUser)@$($cfg.proxmox.host)"
Get-Content "$key.pub" | & ssh.exe -o StrictHostKeyChecking=accept-new $target "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
Write-Host 'Testing key login...'
(Invoke-Ssh 'hostname').Output
