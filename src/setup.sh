#!/bin/bash

# Variables
MACHINE_ARCH=$(uname -m)
INSTALL_SRC_DIR=/opt
TMP_DIR=/tmp
PYTHON3_VENV_ROOT_DIR=${INSTALL_SRC_DIR}/jambula
PYTHON3_VERSION=$(python3 -V | awk '{print $2}' | cut -d '.' -f1-2)
SYSCONFIG_DIR=/etc/default
#
HOME_ASSISTANT_REQUESTED_NEW_VERSION=$1
HOME_ASSISTANT_REQUESTED_OLD_VERSION=$2
HOME_ASSISTANT_PYTHON3_BINARY="python${PYTHON3_VERSION}"
HOME_ASSISTANT_USER=hass
HOME_ASSISTANT_SERVER_IP=$(ip -o -4 addr show | awk '$2 != "lo" && $2 !~ /^docker/ {split($4, a, "/"); if (!found_ipv4++) print a[1]}')
HOME_ASSISTANT_SERVER_PORT=8123

if [[ "$(pwd)" = "/" ]];
then
cat <<ET
Error: Please switch to proper install directory!
ET
exit 1
fi

PROJECT_FUNCTIONS_FILE=/etc/functions
FUNCTIONS_FILE=$(readlink -f $(find . -type f -name functions.sh))
SRC_DIR=$(dirname $FUNCTIONS_FILE)
BASE_DIR=$(dirname ${SRC_DIR})
BIN_DIR=${BASE_DIR}/bin
CONFIG_DIR=${BASE_DIR}/config
PYTHON_DIR=${BASE_DIR}/python
PATCHES_DIR=${BASE_DIR}/patches
PYTHON_ARCHIVES_DIR=${PYTHON_DIR}/archives
SYSTEMD_DIR=${BASE_DIR}/systemd
UDEV_DIR=${BASE_DIR}/udev
SOUNDS_DIR=${BASE_DIR}/sounds
HASS_INSTALL_REQUIREMENTS_FILE=${PYTHON_DIR}/requirements.txt
JAMBULA_ROOTFS_DIR=/jambula
OEM_ADDONS_DIR=${JAMBULA_ROOTFS_DIR}/addons
OEM_SETTINGS_FILE=${OEM_ADDONS_DIR}/settings.conf
HASS_ADDONS_DIR=${OEM_ADDONS_DIR}/home-assistant-core
ZWAVE_ADDONS_DIR=${OEM_ADDONS_DIR}/zwave-js-server
JAMBULA_STORAGE_DIR=${JAMBULA_ROOTFS_DIR}/storage
JAMBULA_SOUNDS_DIR=/usr/share/jambula/sounds

# Define home-assistant-core new versions
HOME_ASSISTANT_DEFAULT_NEW_VERSION=$(basename ${SRC_DIR}/core-* | cut -d '-' -f2 | cut -d '.' -f1-3)
if [[ -z "${HOME_ASSISTANT_REQUESTED_NEW_VERSION}" ]];
then
	HOME_ASSISTANT_NEW_VERSION="${HOME_ASSISTANT_DEFAULT_NEW_VERSION}"

else
	HOME_ASSISTANT_NEW_VERSION="${HOME_ASSISTANT_REQUESTED_NEW_VERSION}"
fi
#
# Define home-assistant-core old versions
HOME_ASSISTANT_DEFAULT_OLD_VERSION=${HOME_ASSISTANT_DEFAULT_NEW_VERSION}
if [[ ! -z ${HOME_ASSISTANT_REQUESTED_OLD_VERSION} ]];
then
	HOME_ASSISTANT_OLD_VERSION="${HOME_ASSISTANT_REQUESTED_OLD_VERSION}"

elif [[ -x /usr/bin/hass ]];
then
	HOME_ASSISTANT_OLD_VERSION="$(/usr/bin/hass --version)"

else
	HOME_ASSISTANT_OLD_VERSION="${HOME_ASSISTANT_DEFAULT_OLD_VERSION}"
fi

# Source configuration for OEM
[[ -e ${OEM_SETTINGS_FILE} ]] && . ${OEM_SETTINGS_FILE}

# Source other project functions
[[ -e ${PROJECT_FUNCTIONS_FILE} ]] && . $PROJECT_FUNCTIONS_FILE

# Source functions
[[ -e ${FUNCTIONS_FILE} ]] && . ${FUNCTIONS_FILE}

# Welcome notice
clear
cat <<ET

#########################################################################################
#                                                                                       #          
#  Welcome to HASS Core Installer!                                                      #
#                                                                                       #
#  You are about to install Home Assistant Core Version: ${HOME_ASSISTANT_NEW_VERSION}  
#                                                                                       #
#  This script will begin shortly.  To cancel, press 'Ctrl+C'                           #
#                                                                                       #
#########################################################################################

ET
sleep 20
clear

# Uninstall previous homeassistant
uninstall_homeassistant_core $HOME_ASSISTANT_OLD_VERSION

# Install latest homeassistant
homeassistant_core_install "$HOME_ASSISTANT_NEW_VERSION" "$HOME_ASSISTANT_PYTHON3_BINARY"

# Configure homeassistant
homeassistant_core_configure

# Completion notice
hass --version > /dev/null 2>&1
HASS_INSTALLED=$?
if [[ "${HASS_INSTALLED}" = "0" ]];
then
clear
cat <<ET

#####################################################################
#                                                                   #
#  Congratulations, completed install and setup of home assistant!  #
#                                                                   #
#  To begin creating your smart home, point your browser to:        #
#                                                                   #
#  http://${HOME_ASSISTANT_SERVER_IP}:${HOME_ASSISTANT_SERVER_PORT}
#                                                                   #   
# NOTE: If you want Home Assistant to always start at boot time,    #
#       run the following command:                                  #
#                                                                   #
#       systemctl enable home-assistant.service                     #
#                                                                   #
#####################################################################

ET
else
cat <<ET

###################################################
  Error:  Installation of Home Assistant Failed!
###################################################

ET
fi
