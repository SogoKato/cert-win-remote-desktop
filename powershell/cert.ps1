function UpdateCert {
    $CERTWSLPATH = '\\wsl$\Ubuntu\home\<user>\cert-win-remote-desktop\wsl\keys'
    $DOMAIN = '<your-domain>'

    $SHA1HashVal = Get-Content "$CERTWSLPATH\fingerprint.txt"
    $CertThumbprint = $SHA1HashVal.Replace(':','')
    $CertParentPath = 'cert:\LocalMachine\My'
    $Certs = Get-ChildItem -Path $CertParentPath -DnsName "*$DOMAIN*"
    foreach ($Cert in $Certs) {
        if ($CertThumbprint -eq $Cert.Thumbprint) {
            Write-Host "CERT IS ALREADY UP-TO-DATE."
            return
        }
    }

    # Delete all items of the same domain before import
    $Certs | Remove-Item
    $DomainReplaced = $DOMAIN.replace('*','ast')
    Import-PfxCertificate -CertStoreLocation Cert:\LocalMachine\My -FilePath "$CERTWSLPATH\$DomainReplaced.pfx"

    # Grant read permission to NETWORK SERVICE
    $CertPath = "$CertParentPath\$CertThumbprint"
    $CertObj= Get-ChildItem -Path $CertPath
    $RsaCert = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($CertObj)
    $FileName = $RsaCert.key.UniqueName
    $CryptoKeysPath = "$env:ALLUSERSPROFILE\Microsoft\Crypto\Keys\$FileName"
    $Permissions = Get-Acl -Path $CryptoKeysPath
    $Rule = new-object security.accesscontrol.filesystemaccessrule "NETWORK SERVICE", "read", allow
    $Permissions.AddAccessRule($Rule)
    Set-Acl -Path $CryptoKeysPath -AclObject $Permissions

    $RegEntryPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'
    $RegEntryName = 'SSLCertificateSHA1Hash'
    $RegEntryProp = $SHA1HashVal.Split(':') | ForEach-Object { "0x$_"}

    $Exists = Get-ItemProperty -Path $RegEntryPath -Name $RegEntryName -ErrorAction SilentlyContinue
    if ($null -ne $Exists) {
        Set-ItemProperty -Path $RegEntryPath -Name $RegEntryName -Value $RegEntryProp
    } else {
        New-ItemProperty -Path $RegEntryPath -Name $RegEntryName -PropertyType Binary -Value ([byte[]]$RegEntryProp)
    }
}
UpdateCert
