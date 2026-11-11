# iDRAC PowerNap

Wake a Dell PowerEdge server on a schedule, let it do its job for a fixed window, then **verify it is really powered off**.
Built for a homelab box that only needs to be on for an hour every couple of weeks (file syncing, backups, updates)
and shouldn't sit idle burning power the rest of the time.

An always-on Windows PC is the controller. It uses IPMI over LAN to talk to iDRAC (which works even when the server is off)
and SSH to ask Proxmox for a clean shutdown.

Developed and tested on a PowerEdge R720xd (iDRAC7) running Proxmox VE. It should work on other iDRAC/IPMI servers.

## What a run does

1. If the server is already on, it **skips the run and never shuts it down**, so it won't kill a session you started.
2. Sends the IPMI power-on command, retrying up to 5 times, and checks via iDRAC that power really came on.
3. Waits for Proxmox to answer on SSH (power-cycles once if it never does).
4. Optionally checks a VM (by Proxmox VM ID) and starts it if it isn't running.
5. Starts the timer once Proxmox is reachable, so boot time doesn't use up your window.
6. Shuts down, escalating if needed:
   graceful SSH `shutdown` (retried) -> iDRAC ACPI soft shutdown -> hard power off.
7. Confirms with iDRAC that the chassis is OFF, logs everything, and optionally sends a push alert (ntfy) on failure.

## Requirements

- Windows PC that stays on (PowerShell 5.1+, built-in OpenSSH client)
- iDRAC with **IPMI over LAN enabled** and an account with IPMI rights
- Proxmox VE reachable over SSH, with the server set to start your VMs at boot
- `ipmitool.exe`, see [tools/README.md](tools/README.md)

## Setup

1. Copy `config/config.example.json` to `config/config.json` and set your iDRAC IP, Proxmox IP, and (optionally) `guestVmId`.
2. Put `ipmitool.exe` in `tools/`.
3. In PowerShell:
   ```powershell
   cd scripts
   .\Initialize-Credentials.ps1   # stores your iDRAC login, encrypted for your Windows user only
   .\Initialize-SSH.ps1           # creates an SSH key and installs it on Proxmox
   .\Test-Setup.ps1               # everything should say PASS
   ```
4. **Do a real test run** with the server off. Set `runtimeMinutes` to about 5 first, then run `.\Start-Maintenance.ps1`
   and confirm in `logs/maintenance.log` that it ends with "Server confirmed OFF".
5. Set `runtimeMinutes` back to what you want and, in an **elevated** PowerShell, run `.\Install-Scheduler.ps1`.
   It creates a Task Scheduler job for 3:00 AM every other Wednesday (edit the script for another schedule).

Run the credentials step and the scheduler as the same Windows user. The saved iDRAC login only works for that user.

## Configuration (`config/config.json`)

| Setting | Meaning |
|---|---|
| `idrac.host` | iDRAC IP address |
| `proxmox.host`, `sshUser` | Proxmox address and SSH user |
| `proxmox.guestVmId` | Optional VM ID to check/start (leave `""` to skip) |
| `ipmitoolPath` | Path to ipmitool.exe (relative to the repo or absolute) |
| `powerOn.maxAttempts` / `verifySeconds` | Power-on retries and how long to wait for each |
| `boot.sshTimeoutMinutes` | How long to wait for Proxmox SSH after power-on |
| `runtimeMinutes` | Length of the work window, counted from when Proxmox is reachable |
| `shutdown.*` | Graceful attempts, wait per attempt, and the soft/hard fallbacks |
| `notify.ntfyUrl` | Optional ntfy.sh topic URL for failure alerts |

## Safety notes

- `hardPowerOffFallback` is **on by default** because the goal is "never leave it running". It only triggers after
  several graceful attempts and an ACPI soft shutdown fail, but a hard power-off can still corrupt data. Turn it off if you prefer.
- Large guests (TrueNAS, databases) can need longer than Proxmox's default ~3 minute guest shutdown timeout.
  Raise it in the VM's Options > Start/Shutdown order.
- Only the iDRAC password is stored (DPAPI-encrypted, per Windows user). The SSH key lives in `ssh/`.
  Both are git-ignored. Don't commit them.
- Use at your own risk. Test with the server off and watch the first run.

## Troubleshooting

- **Credential prompt hangs or shows a blank window:** the scripts use `Read-Host`, not a pop-up, so run them in a normal PowerShell window.
- **Script closes instantly:** run it from an open PowerShell window so you can read the error.
- **ipmitool can't connect:** confirm IPMI over LAN is enabled in iDRAC and the account has IPMI privileges.
- **Task doesn't appear:** run `Install-Scheduler.ps1` from an elevated PowerShell.

## License

MIT
