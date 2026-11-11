# ipmitool for Windows

PowerNap talks to iDRAC with `ipmitool.exe`. Put `ipmitool.exe` (plus any DLLs it needs) in this folder,
or anywhere on your PATH. Binaries are not included in this repo.

Ways to get one:
- Build it from source with Cygwin (project: https://github.com/ipmitool/ipmitool). Enable the lanplus
  interface (`./configure --enable-intf-lanplus`) and copy `ipmitool.exe` plus the Cygwin DLLs it needs
  (cygwin1.dll, cygcrypto, cygz, cygreadline, cygncursesw).
- Use a copy you are licensed to use. Some vendor-packaged builds (for example Dell's service builds) carry
  restrictive licenses, so check before sharing them.

Check it works (password via environment variable, which is how PowerNap calls it):

    $env:IPMI_PASSWORD = "your-idrac-password"
    .\ipmitool.exe -I lanplus -H <idrac-ip> -U root -E chassis power status
