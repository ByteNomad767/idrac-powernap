# Title
iDRAC PowerNap: wake a PowerEdge on a schedule, run for an hour, and *verify* it's off (Proxmox + PowerShell)

# Post

My R720xd only needs to be on about an hour every two weeks (file sync), but it kept ending up running for weeks
because I'd forget or a shutdown would silently fail. So I built **iDRAC PowerNap**.

An always-on Windows PC is the controller. Task Scheduler runs a PowerShell script every other Wednesday at 3 AM, and the script:

- sends an IPMI power-on to iDRAC and **retries up to 5 times**, checking the real chassis power state each time
- waits for Proxmox to answer on SSH (power-cycles once if it never boots)
- starts a timer for your work window only once Proxmox is actually up, so boot time doesn't eat the hour
- shuts down cleanly over SSH, then escalates: more graceful retries, then iDRAC ACPI soft shutdown, then optional hard power-off
- **confirms via iDRAC that the box is really OFF**, logs everything, and can push an ntfy alert if something fails
- **skips the run entirely if the server is already on**, so it never kills a session you started by hand

Credentials are stored with Windows DPAPI (per-user encrypted) and SSH uses a key, so there are no plaintext passwords in the scripts.

Tested on an R720xd (iDRAC7) with Proxmox VE and a TrueNAS VM, but it should work on any iDRAC/IPMI server.
You'll need to supply your own ipmitool.exe (the README explains how).

Repo: https://github.com/ByteNomad767/idrac-powernap

Caveats: the hard power-off fallback is on by default (it's the last resort after graceful attempts fail), so read the
safety notes, test with the server off first, and use at your own risk. Feedback and PRs welcome.
