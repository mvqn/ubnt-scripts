#!/bin/bash

# This script has now been tested on the following:
#
# - Vultr VPS / Debian 9 x64 / 2 CPU / 4GB / 80GB SSD @ $10.00/mo (03/28/2019)
#

echo "===================================================================================================="
echo "PRE-CHECKS"
echo "===================================================================================================="

if [[ $# -eq 0 ]]
then
    echo "Usage: $0 <unms.domain.tld> <ucrm.domain.tld> <email@domain.tld>"
    exit
fi

if [[ $# -ne 3 ]]
then
    echo "Usage: $0 <unms.domain.tld> <ucrm.domain.tld> <email@domain.tld>"
    exit
fi

HOST=`hostname`

UNMS=$1
UCRM=$2
MAIL=$3

# Get an array of all interface IPs...
ips=`ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`

# Build an array of the domains provided for the UCRM and UNMS servers...
domains=(
    ${UNMS}
    ${UCRM}
)

echo ""

for domain in ${domains[@]}
do
    if nslookup "${domain}" >/dev/null 2>&1 ; then
        echo -n "DNS 'A' record found for '${domain}', verifying..."

        dns=`dig +short ${domain}`
        match=0

        for ip in ${ips[@]}
        do
            if [[ "$ip" = "$dns" ]] ;
            then
                match=1
                break
            fi
        done

        if [[ "$match" = "0" ]] ;
        then
            echo "Missing!"
            echo "Please add a DNS 'A' record pointing to this host prior to installation!"
            exit
        else
            echo "Matched (${dns})!"
        fi
    else
        echo "Missing DNS 'A' record for '${domain}'!"
        echo "Please add a DNS 'A' record pointing to this host prior to installation!"
        exit
    fi
done

# TODO: Determine if we need a more complete RegEx patter for all possible valid emails!
REGEX="^[a-z0-9!#\$%&'*+/=?^_\`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_\`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?\$"

echo ""
echo -n "Verifying email address..."

if [[ ${MAIL} =~ $REGEX ]] ; then
    echo "Valid!"
else
    echo "Invalid!"
    exit
fi

echo ""
echo "* All pre-checks have passed, it should be safe to continue."
echo ""

echo "===================================================================================================="
echo "PREPARATION"
echo "===================================================================================================="
echo ""

echo -n "Adding stretch-backports to apt sources for more current Certbot packages..."

if ! (grep -q "# stretch-backports" /etc/apt/sources.list) ;
then
    echo "" >> /etc/apt/sources.list
    echo "# stretch-backports" >> /etc/apt/sources.list
    echo "deb http://deb.debian.org/debian stretch-backports main contrib non-free" >> /etc/apt/sources.list
    echo "deb-src http://deb.debian.org/debian stretch-backports main contrib non-free" >> /etc/apt/sources.list

    echo "Done!"
else
    echo "Existing!"
fi

echo ""

apt update -y

echo ""
echo "* All preparations should now be complete, it should be safe to continue."
echo ""

echo "===================================================================================================="
echo "PROXY SERVER"
echo "===================================================================================================="
echo ""

echo "Installing nginx..."
echo ""

# Install and enable nginx.
apt install -y nginx

echo ""
echo "Enabling nginx..."
echo ""

systemctl enable nginx

echo ""
echo "Adding virtual hosts..."
echo ""

read -r -d "" UNMS_CONF <<EOF
# Redirect UNMS HTTP Requests
server {
    listen 80;
    server_name ${UNMS};

    # NOTE: This would normally need to be enabled for Certbot to complete it's handshake. UNMS,
    # unlike UCRM, does not need to actually create a certificate to enable HTTPS, so we skip this!
    #location / {
    #    proxy_redirect off;
    #    proxy_set_header Host \$host;
    #    proxy_pass http://127.0.0.1:8080/;
    #}

    # Force HTTP to HTTPS redirect here!
    return 301 https://\$server_name\$request_uri;
}

# Handle UNMS HTTPS Requests
server {
    listen 443 ssl http2;
    server_name ${UNMS};

    set \$upstream 127.0.0.1:8443;

    location / {
        proxy_pass     https://\$upstream;
        proxy_redirect https://\$upstream https://\$server_name;

        proxy_cache off;
        proxy_store off;
        proxy_buffering off;
        proxy_http_version 1.1;
        proxy_read_timeout 36000s;

        proxy_set_header Host \$http_host;
        proxy_set_header Upgrade \$http_upgrade;
        #proxy_set_header Connection \$connection_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Referer "";

        client_max_body_size 0;
    }

    # Let's Encrypt Certificates will be included below by Certbot...
}
EOF

echo "${UNMS_CONF}" > /etc/nginx/sites-enabled/unms

read -r -d "" UCRM_CONF <<EOF
# Redirect UCRM HTTP Requests
server {
    listen 80;
    server_name ${UCRM};

    # NOTE: This needs to be here for Certbot to complete it's handshake.
    location / {
        proxy_redirect off;
        proxy_set_header Host \$host;
        proxy_pass http://127.0.0.1:9080/;
    }

    # Unlike UNMS, UCRM will automatically perform it's own HTTP -> HTTPS redirect, so we NEVER need this!
    #return 301 https://\$server_name\$request_uri;
}

# Forward UCRM HTTP Requests for Suspension Pages
server {
    listen 81;
    server_name ${UCRM};

    location / {
        proxy_redirect off;
        proxy_set_header Host \$host;
        proxy_pass http://127.0.0.1:9081/;
    }
}

# Handle UCRM HTTPS Requests
server {
    listen 443 ssl http2;
    server_name ${UCRM};

    set \$upstream 127.0.0.1:9443;

    location / {
        proxy_pass     https://\$upstream;
        proxy_redirect https://\$upstream https://\$server_name;

        proxy_cache off;
        proxy_store off;
        proxy_buffering off;
        proxy_http_version 1.1;
        proxy_read_timeout 36000s;

        proxy_set_header Host \$http_host;
        proxy_set_header Upgrade \$http_upgrade;
        #proxy_set_header Connection \$connection_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Referer "";

        client_max_body_size 0;
    }

    # Let's Encrypt Certificates will be included below by Certbot...
}
EOF

echo "${UCRM_CONF}" > /etc/nginx/sites-enabled/ucrm

echo ""

echo "===================================================================================================="
echo "UNMS INSTALLATION"
echo "===================================================================================================="
echo ""

apt install -y curl bash netcat

curl -fsSL https://unms.com/install > /tmp/unms_inst.sh
bash /tmp/unms_inst.sh --public-https-port 443 --http-port 8080 --https-port 8443

# NOTE: The user will be prompted here for "overcommit memory settings" if 2GB or less of memory on this host!
# NOTE: The user will also be prompted here if UNMS has previously been installed on this host!

echo ""

echo "===================================================================================================="
echo "UCRM INSTALLATION"
echo "===================================================================================================="
echo ""

curl -fsSL https://ucrm.ubnt.com/install > /tmp/ucrm_install.sh
bash /tmp/ucrm_install.sh --http-port 9080 --https-port 9443 --suspension-port 9081 --netflow-port 2056

# TODO: Determine if there is a need to change NetFlow port config, when UCRM is desired NetFlow destination?

echo ""

echo "===================================================================================================="
echo "SSL CERTIFICATE(S)"
echo "===================================================================================================="
echo ""

apt install -y python-certbot-nginx
certbot --nginx -d ${UNMS} -d ${UCRM} --non-interactive --agree-tos -m ${MAIL}

nginx -s reload

echo "Installing nginx..."
echo ""

crontab -l > /tmp/crontab
echo "# Certbot - Let's Encrypt Certificate Renewal" >> /tmp/crontab
echo "0 0 * * * certbot renew --post-hook \"systemctl reload nginx\"" >> /tmp/crontab
crontab /tmp/crontab
rm /tmp/crontab

echo "===================================================================================================="
echo "FINAL INSTRUCTIONS"
echo "===================================================================================================="
echo ""

read -r -d "" INSTRUCTIONS <<EOF
Installation should now be complete, but additional setup will still be required to have a fully
functional UNMS + UCRM server.  The following should now be completed manually:

====================================================================================================
UNMS
====================================================================================================

1.  Navigate to:
    https://${UNMS}
2.  Complete the setup like normal, nothing special.

NOTES:
-   You can choose to leave the "Use Let's Encrypt" box checked or not, UNMS does not seem to care
    one way or the other.  This certificate will not actually be used by the public facing proxy.
-   The following port mappings have been created by default:
    * 80   -> 8080 (w/ forced redirect to HTTPS:443)
    * 443  -> 8443
    * 2055 -> 2055


====================================================================================================
UCRM
====================================================================================================

1.  Navigate to:
    http://${UCRM}:9080
2.  Acknowledge any "Not secure" messages and then complete the setup like normal.
3.  Once setup has been completed, head to System -> Settings -> Server Configuration and be sure to
    set the following:
    * Server domain name: ${UCRM}
    * Server port: 443 (not 9443 or 9080)
    * Server suspension port: 81 (not 9081)
    * DO NOT forget to click the "Save" button before the moving on to the next step.
4.  Then click the link for "set up SSL certificate" or head to System -> Tools -> SSL certificate
    and under the Let's Encrypt section, do the following:
    * Fill in your email address
    * Click the Enable/Update button

NOTES:
-   Step 4 above seems to be required before the UCRM system actually enables HTTPS.  Until it has
    completed, UCRM returns a '502 Bad Gateway' when visiting it's HTTPS URL.  While required to
    enable the HTTPS service, this certificate will not actually be used by the public facing proxy.
-   Step 4 does take a few moments (usually 2-5 minutes), but you should be automatically redirected
    to the HTTPS URL once it has completed.  If not, simply refresh the page.
-   The following port mappings have been created by default:
    * 80   -> 9080 (w/ forced redirect to HTTPS:443)
    * 443  -> 9443
    * 2056 -> 2056 (while still functional on the UCRM side, this may cause problems receiving new
                   NetFlow data in UCRM without special configuration on the NetFlow device).  If
                   you need to have NetFlow data in UCRM on port 2055, then you will be unable to
                   receive the data in UNMS on port 2055.  This decision would only require a few
                   changes to this file, if desired.

====================================================================================================
TO-DO LIST
====================================================================================================

Right now, the only future plans for this script are:
-   To update it with UNMS/UCRM releases until such time that the UNMS+UCRM system is released.
-   Figure out a way to make the UCRM HTTPS/SSL setup (Step 4) automated.
-   Bug fixes

====================================================================================================
CONTACT
====================================================================================================

Any feedback on this script would be greatly appreciated.

All inquiries can be made to my email at: rspaeth@mvqn.net
or on the GitHub page at: https://github.com/mvqn/ucrm-scripts

- Ryan Spaeth
EOF

echo "${INSTRUCTIONS}"
echo ""