# cert-win-remote-desktop
Issue and renew certificate of Let's Encrypt using acme.sh DNS-01 validation, apply new certificate with WSL and Powershell scripts.

# What is this for?
When we use Windows 10 built-in remote desktop, the RD client ask us if we trust the self-signed certificate of the host computer. This is because Windows RD uses self-signed certificate by default. It has no problems for use, however, I am reluctant to be "Never ask again for connections to this PC" checked.

If you want to get SSL certificate to avoid that prompt, this code may help you.

# Prerequires
- You own your domain that is using DNS provider that acme.sh supports
- You are using WSL2

You can find [supported DNS provider from here](https://community.letsencrypt.org/t/dns-providers-who-easily-integrate-with-lets-encrypt-dns-validation/86438).
If your provider is **not** supported by acme.sh, please consider using another ACME client instead. In case your provider is not in list and you can expose 80 port, you can use HTTP-01 challenge (or certbot instead of acme.sh) alternatively (however, that needs to keep 80 open). 

As of September 2020, Certbot for Windows does not support DNS-01 challenge, we need to use Certbot in WSL. In this script, PowerShell accesses files in WSL, and that is feature of WSL2. 

# Steps
1. Install acme.sh and set cron for auto renewal
2. Issue a cert
3. Convert to pfx (Windows format of certificate)
4. Import pfx and do some settings
5. Set scheduled tasks

## 1. Install acme.sh and set cron for auto renewal
Install acme.sh in your WSL environment.

```
$ wget -O -  https://get.acme.sh | sh
```

After you get acme.sh installed, restart your terminal.

### Set cron in WSL
If you already run cron in WSL, cron should be set when installing acme.sh.
Following these steps below, you can run cron process automatically at boot of Windows.
1. Change setting not to ask password when sudo.
```
$ sudo visudo
<username> ALL=NOPASSWD: ALL # add this line (put your username in <username>)
```
2. Make a new file of `wsl /bin/bash -l -c "sudo service cron start"` and save a bat file as a name you defined.
3. Copy (or move) the bat file to `C:\Users\<win-user>\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup`

## 2. Issue a cert
To use DNS-01 challenge, you need to set DNS ID and password (or token or key) as environment variables. You can find designated variables from [dnsapi](https://github.com/acmesh-official/acme.sh/wiki/dnsapi)

For example,
```
$ export MYDNSJP_MasterID=MasterID
$ export MYDNSJP_Password=Password
```

Then, issue a cert like this.
```
$ acme.sh --issue --dns <your-dns-provider> -d <your-domain>
```
**Caution**: Don't specify multiple domains, the cert issued for multiple domains somohow cannot use in Windows remote desktop. You can issue wildcard cert by specifying like this: `-d *.example.com`.

Once acme.sh succeeded to get cert, keys should be in `/home/<user>/.acme.sh/<your-domain>`.

## 3. Convert to pfx (Windows format of certificate)
Using WSL/convert_to_pfx.sh, convert from cer (pem) to pfx. This script also make a `fingerprint.txt` which is SHA-1 hash value of cert.
```
$ cd ~/
$ git clone https://github.com/norocchi/cert-win-remote-desktop.git
$ cd ~/cert-win-remote-desktop/wsl
$ nano convert_to_pfx.sh
# edit $domain and $file_dir
domain='<your-domain>'
file_dir='/home/<user>/cert-win-remote-desktop/wsl'
$ ./convert_to_pfx.sh
```

## 4. Import pfx and do some settings
From here, you will use PowerShell terminal.
Before moving, edit `powershell/cert.ps1`
```
$ cd ~/cert-win-remote-desktop/powershell
$ nano cert.ps1
# edit $CERTWSLPATH and $DOMAIN
$CERTWSLPATH = '\\wsl$\Ubuntu\home\<user>\cert-win-remote-desktop\wsl\keys'
$DOMAIN = '<your-domain>'
```

Move `powershell/cert.ps1` to Windows directory. Use Expolorer or PowerShell command like this:
```
cp \\wsl$\Ubuntu\home\<user>\cert-win-remote-desktop\powershell\cert.ps1 C:\Users\<win-user>\path\to\your\folder
cd C:\Users\<win-user>\path\to\your\folder
```

...and execute command
```
./cert.ps1
```

Open mmc.exe, File > Add Remove Snap-in > Certficates > Add > Computer Account > Local Computer > OK, expand your Personal/Certificates.
If you can see domain name we just added, pfx cert was successfully added to your computer.
Just in case, right-click on the item and choose All Tasks / Manage Private Keys, confirm there is `NETWORK SERVICE`.

Then, open regedit and expand `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp`, find `SSLCertificateSHA1Hash`. If hex values there are as same as values in `fingerprint.txt`, scripts have done their work without an error!

FYI: These scripts are based on [this page](https://superuser.com/questions/1093159/how-to-provide-a-verified-server-certificate-for-remote-desktop-rdp-connection).

## 5. Set scheduled tasks
Now, you should set scheduled tasks for auto renewal.
Using cron in WSL, create a daily job like this:
```
0 0 * * * /path/to/cert-win-remote-desktop/wsl/convert_to_pfx.sh
```

Then, open Task Scheduler in Windows and create a new basic task.
It should run daily with highest privilege, only when user is logged on.
Program/script is `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`, the argument is `C:\Users\<win-user>\path\to\your\folder\cert.ps1`.

All done!

## References
- [An ACME Shell script: acme.sh](https://github.com/acmesh-official/acme.sh)
- [How to provide a verified server certificate for Remote Desktop (RDP) connections to Windows 10](https://superuser.com/questions/1093159/how-to-provide-a-verified-server-certificate-for-remote-desktop-rdp-connection)
- [Certificate Provider](https://docs.microsoft.com/en-us/powershell/module/Microsoft.PowerShell.Security/About/about_Certificate_Provider?view=powershell-7)
- [DNS providers who easily integrate with Let’s Encrypt DNS validation](https://community.letsencrypt.org/t/dns-providers-who-easily-integrate-with-lets-encrypt-dns-validation/86438)
- [Working with Registry Entries](https://docs.microsoft.com/en-us/powershell/scripting/samples/working-with-registry-entries?view=powershell-7)
- [Import-PfxCertificate](https://docs.microsoft.com/en-us/powershell/module/pkiclient/import-pfxcertificate?view=win10-ps)
- [in Japanese - OpenSSLで証明書（PEM）をPKCS #12に変換](https://www.uramiraikan.net/Works/entry-2499.html)
- [Import a Signed Server Certificate into a Windows Certificate Store](https://docs.vmware.com/en/VMware-Horizon-7/7.12/horizon-scenarios-ssl-certificates/GUID-2D968AD7-ED62-46CA-B2B2-CCC526CA09F5.html)
- [Managing Windows PFX certificates through PowerShell](https://dev.to/iamthecarisma/managing-windows-pfx-certificates-through-powershell-3pj)
- [Export a PKCS#12 file without an export password?](https://stackoverflow.com/questions/27497723/export-a-pkcs12-file-without-an-export-password)
- [in Japanese - WSL で cron を利用する方法・Windows 起動時に自動実行する方法](https://loumo.jp/archives/24595)
- [in Japanese - sudo のパスワードを入力なしで使うには](https://qiita.com/RyodoTanaka/items/e9b15d579d17651650b7)
- [MyDNS.JP](https://www.mydns.jp/)
