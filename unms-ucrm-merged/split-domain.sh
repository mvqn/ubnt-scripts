#!/bin/bash

# This script has now been tested on the following:
#
# - Vultr VPS / Debian 9 x64 / 2 CPU / 4GB / 80GB SSD @ $10.00/mo (07/25/2019)
# - UNMS 1.0.0-beta6
#

echo ""
echo "===================================================================================================="
echo "PRE-CHECKS"
echo "===================================================================================================="
echo ""

if [[ $# -ne 3 ]]
then
    echo "Usage: $0 <unms.domain.tld> <ucrm.domain.tld> <email@domain.tld>"
    echo ""
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

if [[ "$(command -v dig)" == "" ]]
then
    echo "Installing 'dnsutils' for 'dig' command..."
    apt install -y dnsutils
    echo ""
fi


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
            echo ""
            exit
        else
            echo "Matched (${dns})!"
            echo ""
        fi
    else
        echo "Missing DNS 'A' record for '${domain}'!"
        echo "Please add a DNS 'A' record pointing to this host prior to installation!"
        echo ""
        exit
    fi
done

# TODO: Determine if we need a more complete RegEx patter for all possible valid emails!
REGEX="^[a-z0-9!#\$%&'*+/=?^_\`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_\`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?\$"

echo -n "Verifying email address..."

if [[ ${MAIL} =~ $REGEX ]] ; then
    echo "Valid!"
else
    echo "Invalid!"
    exit
fi


if ! [ -d "/home/unms/data/cert" ];
then
    echo "Could not find the directory '/home/unms/data/cert/'.  Is UNMS 1.X installed?"
    echo ""
    exit
fi

#if ! [ -f "/home/unms/data/cert/renewal/$UNMS.conf" ];
#then
#    echo "Missing the certificate information at '/home/unms/data/cert/renewal/$HOST.conf'."
#    echo "Was UNMS 1.X installed using the same hostname?"
#    echo ""
#    exit
#fi

echo ""
echo "* All pre-checks have passed, it should be safe to continue."
echo ""

echo "Using the following values for this script:"
echo "    HOST: $HOST"
echo "    UNMS: $UNMS"
echo "    UCRM: $UCRM"
echo "    MAIL: $MAIL"
echo "    CERT: /home/unms/data/cert/"

read -r -p "Continue with these settings? [y/N] " response
response=${response,,} # tolower

if ! [[ "$response" =~ ^(yes|y)$ ]]
then
    echo "Aborting..."
    echo ""
    exit
fi

echo ""
echo "===================================================================================================="
echo "CONFIGURATION"
echo "===================================================================================================="
echo ""

docker cp unms-nginx:/etc/nginx/conf.d/unms\+ucrm-https\+wss.conf /tmp/unms\+ucrm-https\+wss.conf

if ! grep -q "server_name" /tmp/unms\+ucrm-https\+wss.conf;
then
    echo -n "Backing up old nginx configuration..."
    docker exec unms-nginx cp /etc/nginx/conf.d/unms\+ucrm-https\+wss.conf /etc/nginx/conf.d/unms\+ucrm-https\+wss.conf.backup
    echo "Done!"
    echo ""

    echo -n "Configuring nginx in the 'unms-nginx' container..."

    OLD="listen 443;"
    NEW="$OLD\n\n  ##ADDED#\n  server_name $UNMS;\n  server_name $UCRM;\n  #ADDED##"
    sed -i "s/$OLD/$NEW/g" /tmp/unms\+ucrm-https\+wss.conf

    OLD="allow all;"
    NEW="$OLD\n\n    ##ADDED#\n    if (\$http_host = \'$UCRM\') {\n      return 302 https:\/\/\$http_host\/crm\/login;\n    }\n    #ADDED##\n"
    sed -i "s/$OLD/$NEW/g" /tmp/unms\+ucrm-https\+wss.conf

    OLD="include \"ip-whitelist.conf\";"
    NEW="$OLD\n\n    ##ADDED#\n    if (\$http_host = \'$UCRM\') {\n      return 302 https:\/\/$UNMS\$request_uri;\n    }\n    #ADDED##\n"
    sed -i "s/$OLD/$NEW/g" /tmp/unms\+ucrm-https\+wss.conf

    docker cp /tmp/unms\+ucrm-https\+wss.conf unms-nginx:/etc/nginx/conf.d/unms\+ucrm-https\+wss.conf

    echo "Done!"
    echo ""

    echo "Restarting nginx in the 'unms-nginx' container..."
    docker exec unms-nginx nginx -s reload
    echo ""
fi

echo ""
echo "===================================================================================================="
echo "CERTIFICATES"
echo "===================================================================================================="
echo ""

echo "Re-Issuing SSL Certificate using the additional SANs..."
echo ""

options="--expand --non-interactive --webroot --webroot-path /www --config-dir /cert --force-renewal"
domains="-d $UNMS,$UCRM"
email="-m $MAIL"

docker exec unms-nginx certbot certonly $options $domains $email

echo "===================================================================================================="
echo "FINAL INSTRUCTIONS"
echo "===================================================================================================="
echo ""

read -r -d "" INSTRUCTIONS <<EOF
Configuration should now be complete.

====================================================================================================
NOTES
====================================================================================================

1.  Navigating to 'https://${UNMS}/<URI>' will behave exactly the same as before.
2.  Navigating to 'https://${UCRM}/' will no take you to the customer portal directly.
3.  Navigating to 'https://${UCRM}/nms/<URI>' will now redirect you to your UNMS domain,
    given the same URI.
4.  The UNMS domain and UCMR domain can be completely different, if desired.
5.  Both (sub)domains should be SSL Certified.
6.  ***IMPORTANT*** This script will currently need to be run after every UNMS update.

====================================================================================================
TO-DO LIST
====================================================================================================

Right now, the only future plans for this script are:
-   Determine if the majority of people would prefer that ALL /crm/ endpoints fall under the UCRM
    domain, much like what happens with the /nms/ endpoints after using this script.
-   Bug fixes
- Determine if there is a more automated way of handling this after every UNMS update.

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