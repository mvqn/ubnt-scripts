#!/usr/bin/env bash

# This script has now been tested on the following:
#
# - Vultr VPS / Debian 9 x64 / 2 CPU / 4GB / 80GB SSD @ $10.00/mo (04/03/2019)
#

echo ""
echo "===================================================================================================="
echo "PRE-CHECKS"
echo "===================================================================================================="

if [[ $# -eq 0 ]]
then
    echo "Usage: $0 <UNMS IP> <UCRM IP>"
    echo ""
    exit
fi

if [[ $# -ne 2 ]]
then
    echo "Usage: $0 <UNMS IP> <UCRM IP>"
    echo ""
    exit
fi

HOST=`hostname`

UNMS_IP=$1
UCRM_IP=$2

# TODO: Generate some pre-check code to validate IP addresses!

# Check to make sure that both IPs are not the same!
if [[ ${UNMS_IP} == ${UCRM_IP} ]]; then echo "UNMS & UCRM IPs cannot be the same for this to work!"; echo ""; exit; fi

# Get an array of all interface IPs...
ips=(`ip addr show | grep -Po 'inet \K[\d.]+'`)

# Set some flags for matched IPs.
valid_unms_ip=false
valid_ucrm_ip=false

# Loop through all IPs currently configured on this machine...
for ip in ${ips[@]}
do
    # IF the current IP matches the specified UNMS IP, THEN flag the match!
    if [[ ${ip} == ${UNMS_IP} ]]; then valid_unms_ip=true; fi
    # IF the current IP matches the specified UCRM IP, THEN flag the match!
    if [[ ${ip} == ${UCRM_IP} ]]; then valid_ucrm_ip=true; fi
done

# Echo any errors regarding the missing IP configuration(s).
if [[ ${valid_unms_ip} != true ]]; then echo "UNMS IP '${UNMS_IP}' not found on any interface!"; fi
if [[ ${valid_ucrm_ip} != true ]]; then echo "UCRM IP '${UCRM_IP}' not found on any interface!"; fi

# And then provide instructions and exit!
if ! [[ ${valid_unms_ip} == true && ${valid_ucrm_ip} == true  ]];
then
    echo "Please configure both IP addresses on this host before running this script."
    echo ""
    exit;
fi

echo "Found both IP address configured locally!"
echo ""

# NOTE: Probably no need for DNS entry checks at this time, as we are not enforcing certificates directly!
# ...

apt update -y

echo ""
echo "* All preparations should now be complete, it should be safe to continue."
echo ""



echo "===================================================================================================="
echo "UNMS INSTALLATION"
echo "===================================================================================================="
echo ""

# Install any possibly missing dependencies.
apt install -y curl bash netcat

# Install UNMS using the install script and all defaults, this could take a couple of minutes...
curl -fsSL https://unms.com/install > /tmp/unms_inst.sh
bash /tmp/unms_inst.sh

# NOTE: The user will be prompted here for "overcommit memory settings" if 2GB or less of memory on this host!
# NOTE: The user will also be prompted here if UNMS has previously been installed on this host!

echo ""



echo "===================================================================================================="
echo "UNMS SHUTDOWN"
echo "===================================================================================================="
echo ""

# NOTE: We create the list of containers here manually, as the user may have other containers running that
# we do not want to necessarily stop.

# Build an array of container ids from the list of docker images installed by the UNMS install script.
docker_ids=(
    `docker ps -aqf "name=^unms-nginx$"`
    `docker ps -aqf "name=^unms-netflow$"`
    `docker ps -aqf "name=^unms$"`
    `docker ps -aqf "name=^unms-postgres$"`
    `docker ps -aqf "name=^unms-redis$"`
    `docker ps -aqf "name=^unms-rabbitmq$"`
    `docker ps -aqf "name=^unms-fluentd$"`
)

echo "Removing existing UNMS containers..."

# Loop through all of the UNMS containers...
for id in ${docker_ids[@]}
do
    # ...and force removal of each one!
    docker rm -f ${id}
done

echo ""



echo "===================================================================================================="
echo "UNMS SETTINGS"
echo "===================================================================================================="
echo ""

echo -n "Locking inbound container ports for UNMS to the specific IP of '${UNMS_IP}'..."
# Fix-up the 'docker-compose.yml' file with our changes.
sed -i "s#\"80:80\"#\"${UNMS_IP}:80:80\"#" /home/unms/app/docker-compose.yml
sed -i "s#\"443:443\"#\"${UNMS_IP}:443:443\"#" /home/unms/app/docker-compose.yml
sed -i "s#\"2055:2055/udp\"#\"${UNMS_IP}:2055:2055/udp\"#" /home/unms/app/docker-compose.yml
echo "Complete!"
echo ""

# NOTE: Let's leave these removed for the moment, as it will prevent port conflicts while installing UCRM!



echo "===================================================================================================="
echo "UCRM INSTALLATION"
echo "===================================================================================================="
echo ""

curl -fsSL https://ucrm.ubnt.com/install > /tmp/ucrm_install.sh
bash /tmp/ucrm_install.sh

echo ""



echo "===================================================================================================="
echo "UCRM SETTINGS"
echo "===================================================================================================="
echo ""

echo -n "Locking inbound container ports for UCRM to the specific IP of '${UCRM_IP}'..."
# Fix-up the 'docker-compose.yml' file with our changes.
sed -i "s#80:80#\"${UCRM_IP}:80:80\"#" /home/ucrm/docker-compose.yml
sed -i "s#81:81#\"${UCRM_IP}:81:81\"#" /home/ucrm/docker-compose.yml
sed -i "s#443:443#\"${UCRM_IP}:443:443\"#" /home/ucrm/docker-compose.yml
sed -i "s#2055:2055/udp#\"${UCRM_IP}:2055:2055/udp\"#" /home/ucrm/docker-compose.yml
echo "Complete!"
echo ""



echo "===================================================================================================="
echo "SYSTEM STARTUP"
echo "===================================================================================================="
echo ""

# NOTES: We need to be sure to restart the UCRM services here first, as they are still using the ports we
# need to start UNMS.  Upon restart, they will only be assigned to the provided IP.

echo -n "Starting UCRM..."
docker-compose -f /home/ucrm/docker-compose.yml up -d
echo ""

echo -n "Starting UNMS..."
docker-compose -f /home/unms/app/docker-compose.yml up -d
echo ""



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
    http(s)://${UNMS_IP}
2.  Complete the setup like normal, nothing special.

====================================================================================================
UCRM
====================================================================================================

1.  Navigate to:
    http://${UCRM_IP}
2.  Acknowledge any "Not secure" messages and then complete the setup like normal.
3.  Setup your SSL Certificate in the normal fashion.

====================================================================================================
TO-DO LIST
====================================================================================================

Right now, the only future plans for this script are:
-   To update it with UNMS/UCRM releases until such time that the UNMS+UCRM system is released.
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