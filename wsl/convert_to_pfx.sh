#!/bin/sh
domain='<your-domain>'
file_dir='/home/<user>/cert-win-remote-desktop/wsl'
domain_replaced=`echo $domain | sed -e 's/\*/ast/g'`
pfx_path="${file_dir}/keys/${domain_replaced}.pfx"
fingerprint_path="${file_dir}/keys/fingerprint.txt"

openssl pkcs12 -export \
-in "/home/${USER}/.acme.sh/${domain}/fullchain.cer" \
-inkey "/home/${USER}/.acme.sh/${domain}/${domain}.key" \
-out ${pfx_path} \
-passout pass:

openssl pkcs12 -in ${pfx_path} -nodes -passin pass: \
| openssl x509 -noout -fingerprint \
| awk '{print substr($0, 18)}' \
> ${fingerprint_path}
