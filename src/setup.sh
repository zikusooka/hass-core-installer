#!/bin/bash

# Variables
MACHINE_ARCH=$(uname -m)
INSTALL_SRC_DIR=/opt
SYSCONFIG_DIR=/etc/default
TMP_DIR=/tmp
#
HOME_ASSISTANT_REQUESTED_NEW_VERSION=$1
HOME_ASSISTANT_REQUESTED_OLD_VERSION=$2
#
PYTHON_VERSION_REQUESTED=$3
PYTHON_VERSION_DEFAULT="3.13"
PYTHON_VENV_ROOT_DIR=${INSTALL_SRC_DIR}/jambula
#
HOME_ASSISTANT_USER=hass
HOME_ASSISTANT_SERVER_IP=$(ip -o -4 addr show | awk '$2 != "lo" && $2 !~ /^docker/ {split($4, a, "/"); if (!found_ipv4++) print a[1]}')
HOME_ASSISTANT_SERVER_PORT=8123
HOME_ASSISTANT_RELEASES_API="https://api.github.com/repos/home-assistant/core/releases/latest"
HOME_ASSISTANT_RELEASES_REPO="https://github.com/home-assistant/core/archive/refs/tags"
HASS_CORE_INSTALLER_LOG=/var/log/hass-core-installer.log


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


# Source configuration for OEM
[[ -e ${OEM_SETTINGS_FILE} ]] && . ${OEM_SETTINGS_FILE}

# Source other project functions
[[ -e ${PROJECT_FUNCTIONS_FILE} ]] && . $PROJECT_FUNCTIONS_FILE

# Source functions
[[ -e ${FUNCTIONS_FILE} ]] && . ${FUNCTIONS_FILE}

# Remove previous log file
[[ -f ${HASS_CORE_INSTALLER_LOG} ]] && rm -f ${HASS_CORE_INSTALLER_LOG}


# Set Python version
if [[ -z "${PYTHON_VERSION_REQUESTED}" ]];
then
	PYTHON_VERSION="${PYTHON_VERSION_DEFAULT}"
else
	PYTHON_VERSION=$(echo "${PYTHON_VERSION_REQUESTED}" |  cut -d '.' -f1-2)
fi

# Set default Home-Assistant version
check_if_internet_is_up
#
if [[ "${INTERNET_ALIVE}" = "0" ]];
then
HOME_ASSISTANT_DEFAULT_NEW_VERSION=$(curl -k -s ${HOME_ASSISTANT_RELEASES_API} | jq -r '.tag_name')
HOME_ASSISTANT_DEFAULT_OLD_VERSION=$(basename -s .tar.gz $(ls -Rt ${SRC_DIR}/core-* | head -1) | cut -d '-' -f2-)
else
HOME_ASSISTANT_DEFAULT_NEW_VERSION=$(basename -s .tar.gz $(ls -Rt ${SRC_DIR}/core-* | head -1) | cut -d '-' -f2-)
HOME_ASSISTANT_DEFAULT_OLD_VERSION=$(basename -s .tar.gz $(ls -Rt ${SRC_DIR}/core-* | head -2 | tail -1) | cut -d '-' -f2-)
fi
#
# Set actual Home-Assistant version
if [[ -z "${HOME_ASSISTANT_REQUESTED_NEW_VERSION}" ]];
then
	HOME_ASSISTANT_NEW_VERSION="${HOME_ASSISTANT_DEFAULT_NEW_VERSION}"
else
	HOME_ASSISTANT_NEW_VERSION="${HOME_ASSISTANT_REQUESTED_NEW_VERSION}"
fi
#
# Define home-assistant-core old versions
if [[ ! -z ${HOME_ASSISTANT_REQUESTED_OLD_VERSION} ]];
then
	HOME_ASSISTANT_OLD_VERSION="${HOME_ASSISTANT_REQUESTED_OLD_VERSION}"
	INSTALL_TYPE="Upgrade to"
elif [[ -x /usr/bin/hass ]];
then
	HOME_ASSISTANT_OLD_VERSION="$(/usr/bin/hass --version)"
	INSTALL_TYPE="Install"
else
	HOME_ASSISTANT_OLD_VERSION="${HOME_ASSISTANT_DEFAULT_OLD_VERSION}"
	INSTALL_TYPE="Install"
fi

# Welcome notice
clear
cat <<ET

 |   |                        ___|                    _ _|            |         | |           
 |   |  _\` |  __|  __|       |      _ \   __| _ \       |  __ \   __| __|  _\` | | |  _ \  __| 
 ___ | (   |\__ \\__ \_____| |     (   | |    __/_____| |  |   |\__ \ |   (   | | |  __/ |    
_|  _|\__,_|____/____/      \____|\___/ _|  \___|     ___|_|  _|____/\__|\__,_|_|_|\___|_|    
 

############################################################################################
#                                                                                          #          
#  Welcome to HASS Core Installer!  You are about to ${INSTALL_TYPE} Home Assistant Core
#											   #
#											   #
#		Home Assistant Version:		${HOME_ASSISTANT_NEW_VERSION}		
#											   #
#		Python Version:			${PYTHON_VERSION}
#								       			   #
#											   #
#  Please wait or to cancel, press 'Ctrl+C'                                                #
#                                                                                          #
############################################################################################

ET
sleep 5
clear

# Uninstall previous homeassistant
uninstall_homeassistant_core $HOME_ASSISTANT_OLD_VERSION

# Install latest homeassistant
homeassistant_core_install "$HOME_ASSISTANT_NEW_VERSION"

# Configure homeassistant
homeassistant_core_configure

# Run tests to verify homeassistant installed properly
run_homeassistant_core_tests
