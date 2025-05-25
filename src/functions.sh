#!/bin/bash

check_if_internet_is_up () {
ping -c 1 -W 2 8.8.4.4 > /dev/null 2>&1
INTERNET_ALIVE=$?
}

set_variables_4_python3_virtual_environment () {
VENV_PACKAGE_NAME_VERSION=$1
VENV_HOME_DIR=$PYTHON_VENV_ROOT_DIR/${VENV_PACKAGE_NAME_VERSION}
VENV_BIN_DIR=$VENV_HOME_DIR/bin
VENV_SITE_DIR=$VENV_HOME_DIR/lib/python$VENV_PYTHON_VERSION/site-packages
PYTHON_DOWNLOADS_DIR=${PYTHON_ARCHIVES_DIR}
PYTHON_CMD=$VENV_BIN_DIR/python3
PIP3_CMD=$VENV_BIN_DIR/pip3
UV_CMD=$VENV_BIN_DIR/uv
#
# Activate virtual environment
[[ -x $VENV_HOME_DIR/bin/activate ]] && source $VENV_HOME_DIR/bin/activate
}

download_python_package_using_pip () {
PYTHON_PACKAGE=$1
PYTHON_PACKAGE_FORMAT=$2
PYTHON_VENV_NAME=$3
#
# source variables for python3 virtual environment
set_variables_4_python3_virtual_environment ${PYTHON_VENV_NAME}
#
case $PYTHON_PACKAGE_FORMAT in
wheel)
$PIP3_CMD --disable-pip-version-check download --prefer-binary -d $PYTHON_DOWNLOADS_DIR $PYTHON_PACKAGE
;;

source)
$PIP3_CMD --disable-pip-version-check download --no-binary :all: --only-binary none -d $PYTHON_DOWNLOADS_DIR $PYTHON_PACKAGE
;;

all|both)
$PIP3_CMD --disable-pip-version-check download --prefer-binary -d $PYTHON_DOWNLOADS_DIR $PYTHON_PACKAGE
$PIP3_CMD --disable-pip-version-check download --no-binary :all: --only-binary none -d $PYTHON_DOWNLOADS_DIR $PYTHON_PACKAGE
;;

*)
$PIP3_CMD --disable-pip-version-check download --prefer-binary -d $PYTHON_DOWNLOADS_DIR $PYTHON_PACKAGE
;;
esac
}

install_python_package_using_name () {
PYTHON_PACKAGE=$1
PYTHON_VENV_NAME=$2
#
# source variables for python3 virtual environment
set_variables_4_python3_virtual_environment ${PYTHON_VENV_NAME}
#
# Install locally stored package using specified package name
if [[ ! -z "${PYTHON_PACKAGE}" ]];
then
	${UV_CMD} pip install --no-cache-dir --force-reinstall --link-mode=copy \
	--no-index --find-links $PYTHON_ARCHIVES_DIR ${PYTHON_PACKAGE} || \
echo "Failed to install ${PYTHON_PACKAGE}" >> ${HASS_CORE_INSTALLER_LOG} 2>&1
fi
}

install_python_package_using_requirements () {
PYTHON_REQUIREMENTS_FILE=$1
PYTHON_VENV_NAME=$2
#
# source variables for python3 virtual environment
set_variables_4_python3_virtual_environment ${PYTHON_VENV_NAME}
#
# Install locally stored packages using equirements file specified
${UV_CMD} pip install --no-cache-dir --upgrade --link-mode=copy --no-index \
	--find-links $PYTHON_ARCHIVES_DIR --requirements ${PYTHON_REQUIREMENTS_FILE} || \
echo "Failed to install $PACKAGE" >> ${HASS_CORE_INSTALLER_LOG} 2>&1
}

install_requisite_package_4_venv () {
# Install packages when Internet is available
check_if_internet_is_up
#
if [[ "${INTERNET_ALIVE}" = "0" ]];
then
	$(which uv) pip install --no-cache-dir --upgrade --link-mode=copy $1
else
	$(which uv) pip install --no-cache-dir --upgrade --link-mode=copy --no-index \
		--find-links $PYTHON_ARCHIVES_DIR $1
fi
}

remove_python3_virtual_environment () {
# Delete python3 virtual environment for [PACKAGE]
# Usage: remove_python3_virtual_environment [PACKAGE] [VERSION_STRING]
#   e.g. remove_python3_virtual_environment homeassistant 202173
VENV_PACKAGE=$1
VENV_PACKAGE_VERSION_STRING=$2

# Delete virtual environment
if [[ "x$VENV_PACKAGE_VERSION_STRING" != "x" ]] && [[ -d $PYTHON_VENV_ROOT_DIR/$VENV_PACKAGE-${VENV_PACKAGE_VERSION_STRING} ]];
then
echo "Destroying previous virtual environment [$VENV_PACKAGE-${VENV_PACKAGE_VERSION_STRING}], please be patient ..."
rm -rf $PYTHON_VENV_ROOT_DIR/$VENV_PACKAGE-${VENV_PACKAGE_VERSION_STRING}
elif [[ -d $PYTHON_VENV_ROOT_DIR/$VENV_PACKAGE ]];
then
echo "Destroying previous virtual environment [$VENV_PACKAGE], please be patient ..."
rm -rf $PYTHON_VENV_ROOT_DIR/$VENV_PACKAGE
else
echo "No previous virtual installations found, proceeding ..." 
fi
}

create_python3_virtual_environment () {
# Create python3 virtual environment for [PACKAGE]
# Usage: create_python3_virtual_environment [PYTHON_VERSION] [PACKAGE] [USER]
#   e.g. create_python3_virtual_environment python3.13 homeassistant jambula
VENV_PYTHON_VERSION=$1
VENV_PACKAGE=$2
VENV_USER=$3
#
# source variables for python3 virtual environment
set_variables_4_python3_virtual_environment ${VENV_PACKAGE}
#
# Create user if doesn't exist
id $VENV_USER > /dev/null 2>&1
VENV_USER_EXISTS=$?
if [[ "$VENV_USER_EXISTS" != "0" ]];
then
echo "Creating new user [$VENV_USER] ..."
useradd -mr $VENV_USER
fi
#
# Remove existing directory
[[ -d $VENV_HOME_DIR ]] && rm -rf $VENV_HOME_DIR
# Make virtual environment directory
if [[ ! -d $PYTHON_VENV_ROOT_DIR ]];
then
mkdir -p $PYTHON_VENV_ROOT_DIR
chown -R $VENV_USER:$VENV_USER $PYTHON_VENV_ROOT_DIR 
fi
#
# Switch to virtual environment directory
cd $PYTHON_VENV_ROOT_DIR
#
# Create virtual environment
echo "Creating new virtual environment [$VENV_PACKAGE], please be patient ..."
sudo -u $VENV_USER $(which uv) venv --python $VENV_PYTHON_VERSION $PYTHON_VENV_ROOT_DIR/$VENV_PACKAGE
#
# Activate virtual environment
echo "Activating virtual environment [$VENV_PACKAGE], please be patient ..."
source $VENV_BIN_DIR/activate
#
# Install pip3 for use in virtual environment
install_requisite_package_4_venv pip
#
# Install other key packages for use in virtual environment: # uv, setuptools, wheels
for PACKAGE in \
uv \
setuptools \
wheel
do
install_requisite_package_4_venv $PACKAGE
done
}


# --------------------------
# Uninstallation of packages
# --------------------------
uninstall_homeassistant_core () {
HOME_ASSISTANT_OLD_VERS_STRING=$(echo $1 | sed "s/\.//g") 
#
# Stop any running instance of homeassistant
UNIT=home-assistant && \
	systemctl -q is-active ${UNIT}.service && systemctl -q disable --now ${UNIT}.service || \
	killall hass > /dev/null 2>&1

# Destroy python 3 virtual environment for home-assistant-core 
remove_python3_virtual_environment home-assistant-core $HOME_ASSISTANT_OLD_VERS_STRING

# Remove installation sources directory
[[ -d $INSTALL_SRC_DIR/home-assistant-core-${HOME_ASSISTANT_OLD_VERS_STRING} ]] && \
	rm -rf $INSTALL_SRC_DIR/home-assistant-core-${HOME_ASSISTANT_OLD_VERS_STRING}

# Remove symlink to HASS config directory
[[ -L /etc/homeassistant ]] && rm -f /etc/homeassistant

# Remove HASS binary and symlinks
[[ -L /usr/bin/hass-${HOME_ASSISTANT_OLD_VERS_STRING} ]] && \
	rm -f /usr/bin/hass-${HOME_ASSISTANT_OLD_VERS_STRING}
[[ -L /usr/bin/hass ]] && rm -f /usr/bin/hass

# Remove default sysconfig file for HASS
[[ -e $SYSCONFIG_DIR/home-assistant-core ]] && rm -f $SYSCONFIG_DIR/home-assistant-core

# Remove user
deluser $HOME_ASSISTANT_USER > /dev/null 2>&1
}


# ------------------------
# Installation of packages
# ------------------------
extract_homeassistant_core_sources () {
#
check_if_internet_is_up
#
if [[ "${INTERNET_ALIVE}" = "0" ]];
then
	# Fetch archive of Home-Assistant Core from upstream
	[[ -s ${TMP_DIR}/home-assistant-core-${HOME_ASSISTANT_NEW_VERS_STRING}.tar.gz ]] || \
		wget --no-check-certificate -c -O ${TMP_DIR}/home-assistant-core-${HOME_ASSISTANT_NEW_VERS_STRING}.tar.gz ${HOME_ASSISTANT_RELEASES_REPO}/${HOME_ASSISTANT_NEW_VERSION}.tar.gz 
	# Unpack archive of Home-Assistant Core locally
	cd ${INSTALL_SRC_DIR} && tar zxvf ${TMP_DIR}/home-assistant-core-${HOME_ASSISTANT_NEW_VERS_STRING}.tar.gz \
		--one-top-level=home-assistant-core-${HOME_ASSISTANT_NEW_VERS_STRING} \
		--strip-components=1 
elif [[ "${INTERNET_ALIVE}" != "0" ]] && [[ -f "${SRC_DIR}/core-${HOME_ASSISTANT_NEW_VERSION}.tar.gz" ]];
then
	echo "Warning: Unable to not connect to the Internet using pre-packaged archive [core-${HOME_ASSISTANT_NEW_VERS_STRING}.tar.gz"

	# Unpack archive of Home-Assistant Core locally
	cd ${INSTALL_SRC_DIR} && tar zxvf ${SRC_DIR}/core-${HOME_ASSISTANT_NEW_VERSION}.tar.gz \
		--one-top-level=home-assistant-core-${HOME_ASSISTANT_NEW_VERS_STRING} \
		--strip-components=1
else
	echo "Installation of Home-Assistant-Core failed.  The archive [core-${HOME_ASSISTANT_NEW_VERS_STRING}.tar.gz] is not available"
exit 1
fi
}

install_pre_packaged_hass_core_dependencies () {
# Forcefully add pre-packaged dependencies that are required to install Home-Assistant on Arm64 boards
# NOTE: This is a temporary workaround as many aarch64 based packages are still being built at this time
#
PRE_PACKAGED_DEPS_FILE=${PYTHON_DIR}/requirements-pre-packaged.txt
#
if [[ "${MACHINE_ARCH}" = "aarch64" ]];
then
	grep -v -e "^#" -e 1000000000 ${PRE_PACKAGED_DEPS_FILE} | sed "/^$/d" | \
		while read PACKAGE;
		do
			# Install pre-packaged package using local archive
			install_python_package_using_name ${PACKAGE} home-assistant-core-${HOME_ASSISTANT_NEW_VERS_STRING}
		done
fi
}

revice_versions_on_problematic_hass_core_dependencies () {
HOME_ASSISTANT_NEW_VERS_STRING=$(echo $HOME_ASSISTANT_NEW_VERSION | sed "s/\.//g")
HOME_ASSISTANT_INSTALL_PKG_CONSTRAINTS_FILE=$INSTALL_SRC_DIR/home-assistant-core-${HOME_ASSISTANT_NEW_VERS_STRING}/homeassistant/package_constraints.txt
}

install_hass_core_dependencies_internet_on () {
HOME_ASSISTANT_NEW_VERS_STRING=$(echo $HOME_ASSISTANT_NEW_VERSION | sed "s/\.//g")
HOME_ASSISTANT_INSTALL_PKG_CONSTRAINTS_FILE=$INSTALL_SRC_DIR/home-assistant-core-${HOME_ASSISTANT_NEW_VERS_STRING}/homeassistant/package_constraints.txt
#
# Install dependencies needed by Home-Assistant during installation if Internet is active
grep -v -e "^#" -e 1000000000 ${HOME_ASSISTANT_INSTALL_PKG_CONSTRAINTS_FILE} | sed "/^$/d" | \
	while read PACKAGE;
	do
		# Download package and save it in archive directory
		download_python_package_using_pip ${PACKAGE} all home-assistant-core-${HOME_ASSISTANT_NEW_VERS_STRING}
		# Install package using local archive
		install_python_package_using_name ${PACKAGE} home-assistant-core-${HOME_ASSISTANT_NEW_VERS_STRING}
	done
}

install_hass_core_dependencies_internet_off () {
HOME_ASSISTANT_NEW_VERS_STRING=$(echo $HOME_ASSISTANT_NEW_VERSION | sed "s/\.//g")
HOME_ASSISTANT_INSTALL_PKG_CONSTRAINTS_FILE=$INSTALL_SRC_DIR/home-assistant-core-${HOME_ASSISTANT_NEW_VERS_STRING}/homeassistant/package_constraints.txt
#
# Install dependencies needed by Home-Assistant during installation there's NO if Internet
grep -v -e "^#" -e 1000000000 ${HOME_ASSISTANT_INSTALL_PKG_CONSTRAINTS_FILE} | sed "/^$/d" | \
	while read PACKAGE;
	do
	# Install package from archives directory
		install_python_package_using_name ${PACKAGE} home-assistant-core-${HOME_ASSISTANT_NEW_VERS_STRING} || \
		echo "Warning: Failed to install $PACKAGE" >> ${HASS_CORE_INSTALLER_LOG} 2>&1
	done
}

install_hass_core_required_packages () {
HOME_ASSISTANT_NEW_VERS_STRING=$(echo $HOME_ASSISTANT_NEW_VERSION | sed "s/\.//g")
HOME_ASSISTANT_INSTALL_ALL_REQUIREMENTS_FILE=$INSTALL_SRC_DIR/home-assistant-core-${HOME_ASSISTANT_NEW_VERS_STRING}/requirements_all.txt
#
grep -v -e "^#" -e 1000000000 ${HASS_INSTALL_REQUIREMENTS_FILE} | sed "/^$/d" | cut -d '=' -f1 | \
	while read REQUIRED_PACKAGE;
	do
		# Install required homeassistant core packages based on Internet availability
		if [[ "${INTERNET_ALIVE}" = "0" ]];
		then
			PACKAGE=$(grep "\b${REQUIRED_PACKAGE}\b" ${HOME_ASSISTANT_INSTALL_ALL_REQUIREMENTS_FILE} | grep -v -e "^#" -e 1000000000)
			# Download package and save it in archive directory
			download_python_package_using_pip "${PACKAGE}" all home-assistant-core-${HOME_ASSISTANT_NEW_VERS_STRING}
			# Install package using local archive
			[[ ! -z ${PACKAGE} ]] && echo "Installing [${PACKAGE}]" && \
			install_python_package_using_name "${PACKAGE}" home-assistant-core-${HOME_ASSISTANT_NEW_VERS_STRING}
		else
			# Install package using local archive
			PACKAGE=$(grep "\b${REQUIRED_PACKAGE}\b" ${HOME_ASSISTANT_INSTALL_ALL_REQUIREMENTS_FILE} | grep -v -e "^#" -e 1000000000)
			[[ ! -z ${PACKAGE} ]] && echo "Installing [${PACKAGE}]" && \
			install_python_package_using_name "${PACKAGE}" home-assistant-core-${HOME_ASSISTANT_NEW_VERS_STRING}
		fi
	done
}

homeassistant_core_post_install_cmds () {
HOME_ASSISTANT_NEW_VERS_STRING=$(echo $HOME_ASSISTANT_NEW_VERSION | sed "s/\.//g")
# Create symbolic links
[[ -x /usr/bin/hass-${HOME_ASSISTANT_NEW_VERS_STRING} ]] || \
	ln -s $VENV_BIN_DIR/hass /usr/bin/hass-${HOME_ASSISTANT_NEW_VERS_STRING}
[[ -x /usr/bin/hass-${HOME_ASSISTANT_NEW_VERS_STRING} ]] && \
	ln -s -f /usr/bin/hass-${HOME_ASSISTANT_NEW_VERS_STRING} /usr/bin/hass
#
# Create environment variables file for home-assistant-core
cat > $SYSCONFIG_DIR/home-assistant-core <<ET
HOME_ASSISTANT_NEW_VERS_STRING="${HOME_ASSISTANT_NEW_VERS_STRING}"
HOME_ASSISTANT_CMD="/usr/bin/hass-\${HOME_ASSISTANT_NEW_VERS_STRING}"
HOME_ASSISTANT_CONFIG_DIR=/etc/homeassistant-\${HOME_ASSISTANT_NEW_VERS_STRING}
HOME_ASSISTANT_USER=${HOME_ASSISTANT_USER}
HOME_ASSISTANT_PATH="${INSTALL_SRC_DIR}/jambula/home-assistant-core-\${HOME_ASSISTANT_NEW_VERS_STRING}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/hass/.local/bin"
PATH=\${HOME_ASSISTANT_PATH}              
ET
#
# Remove sources in install directory to save on space
[[ -d $INSTALL_SRC_DIR/home-assistant-core-${HOME_ASSISTANT_NEW_VERS_STRING} ]] && \
	rm -rf $INSTALL_SRC_DIR/home-assistant-core-${HOME_ASSISTANT_NEW_VERS_STRING}
}

homeassistant_core_install () {
HOME_ASSISTANT_NEW_VERS_STRING=$(echo $HOME_ASSISTANT_NEW_VERSION | sed "s/\.//g")
HOME_ASSISTANT_PYTHON_VENV="home-assistant-core-$HOME_ASSISTANT_NEW_VERS_STRING"
#
# source variables for python3 virtual environment
set_variables_4_python3_virtual_environment ${HOME_ASSISTANT_PYTHON_VENV}
#
# Create python 3 virtual environment for home-assistant-core using python version requested
create_python3_virtual_environment ${PYTHON_VERSION} ${HOME_ASSISTANT_PYTHON_VENV} jambula
#
# Prepare home-assistant-core sources
extract_homeassistant_core_sources
#
# Revise version for some problematic packages in requirements constraints file
revice_versions_on_problematic_hass_core_dependencies

# Change to sources directory
cd $INSTALL_SRC_DIR/home-assistant-core-${HOME_ASSISTANT_NEW_VERS_STRING}
#
# Build translation files
$PYTHON_CMD -m script.translations develop --all
#
# Forcefully add pre-packaged dependencies that are required to install Home-Assistant on Arm64 boards
install_pre_packaged_hass_core_dependencies
#
# Install source files based on Internet availability
if [[ "${INTERNET_ALIVE}" = "0" ]];
then
	# Install homeassistant when Internet is available
	install_hass_core_dependencies_internet_on
else
	# Install homeassistant when Internet is NOT available
	install_hass_core_dependencies_internet_off
fi
# 
# Install Home Assistant Core
clear
cat <<ET

Installing Home Assistant Core [${HOME_ASSISTANT_NEW_VERSION}], please be patient ...

ET
install_python_package_using_name "." \
	home-assistant-core-${HOME_ASSISTANT_NEW_VERS_STRING}
#
# Install other packages required during Home-Assistant runtime
cat <<ET


Installing Other runtime requirements needed for Home Assistant Core [${HOME_ASSISTANT_NEW_VERSION}], please be patient ...
------

ET
install_hass_core_required_packages
#
# Post installation setup
homeassistant_core_post_install_cmds
}

homeassistant_core_configure () {
HOME_ASSISTANT_NEW_VERS_STRING=$(echo $HOME_ASSISTANT_NEW_VERSION | sed "s/\.//g") 
HOME_ASSISTANT_CONFIG_DIR=/etc/homeassistant-${HOME_ASSISTANT_NEW_VERS_STRING}
#
# Source HASS runtime variables
. $SYSCONFIG_DIR/home-assistant-core

# Add homeassistant user and add to dialout group so they can access USB Z radio stick
# Check the type of adduser command installed
busybox adduser --help > /dev/null 2>&1
BB_ADDUSER=$?
if [[ "${BB_ADDUSER}" = "0" ]];
then
	adduser -g "Home Assistant User" -G dialout -h /home/${HOME_ASSISTANT_USER} -D $HOME_ASSISTANT_USER 
else
	useradd -c "Home Assistant User" -G dialout -d /home/${HOME_ASSISTANT_USER} -m $HOME_ASSISTANT_USER 
fi
#
# Give HASS user permissions to install packages in Python virtual environment
chown -R $HOME_ASSISTANT_USER $VENV_HOME_DIR
#
# Give HASS user permissions to run CLI commands used by some system sensors
[[ -d /etc/sudoers.d ]] || mkdir /etc/sudoers.d
#
cat > /etc/sudoers.d/${HOME_ASSISTANT_USER} <<ET
Defaults:${HOME_ASSISTANT_USER}    !requiretty
Cmnd_Alias SU_COMMANDS = /usr/bin/hostapd_cli
${HOME_ASSISTANT_USER}	ALL = NOPASSWD: SU_COMMANDS
ET
# Change sudoer file permissions
chmod 0440 /etc/sudoers.d/${HOME_ASSISTANT_USER}
#
# Remove HA_VERSION file if empty
[[ -e ${HOME_ASSISTANT_CONFIG_DIR}/.HA_VERSION ]] && rm -f ${HOME_ASSISTANT_CONFIG_DIR}/.HA_VERSION

# Use OEM directory if it exists
if [[ -d "$HASS_ADDONS_DIR" ]];
then
# -----------------------------------------------------------------------------------
# Home-Assistant configuration for Jambula
# -----------------------------------------------------------------------------------
# Create media directories
for DIRECTORY in ${MEDIA_DIRECTORIES}
do
[[ -d ${JAMBULA_STORAGE_DIR}/${DIRECTORY} ]] || mkdir -p ${JAMBULA_STORAGE_DIR}/${DIRECTORY}
[[ -d ${JAMBULA_STORAGE_DIR}/${DIRECTORY} ]] && \
	chown -R $HOME_ASSISTANT_USER:$HOME_ASSISTANT_USER ${JAMBULA_STORAGE_DIR}/${DIRECTORY}
done
#
# Copy homeassistant configuration files
[[ -d $HASS_ADDONS_DIR/config/homeassistant ]] && \
	cd ${TMP_DIR} && rsync -av $HASS_ADDONS_DIR/config/homeassistant/ $HOME_ASSISTANT_CONFIG_DIR/
#
# Copy udev rules 4 home automation controllers - ttyUSB*
cp -v $HASS_ADDONS_DIR/udev/90-jambula-usb-zwave.rules /etc/udev/rules.d
# Reload udev
/usr/bin/udevadm control --reload && udevadm trigger --action=add
#
# Copy jambulatv-homeassistant-secrets script, if it does not exist in bin directory
[ -e $HASS_ADDONS_DIR/bin/jambula-homeassistant-secrets ] && \
	cp -v $HASS_ADDONS_DIR/bin/jambula-homeassistant-secrets /usr/bin/
# Make script executable
chmod 755 /usr/bin/jambula-homeassistant-secrets
#
# Copy homeassistant sound files
cd ${TMP_DIR} && rsync -av ${HASS_ADDONS_DIR}/sounds/ $JAMBULA_SOUNDS_DIR/homeassistant/
# Change ownership of sounds directory
chown -R $HOME_ASSISTANT_USER:$HOME_ASSISTANT_USER $JAMBULA_SOUNDS_DIR/homeassistant/

# -------------------------------
# Extra features for Jambula
# -------------------------------
	# Zwave JS Server
	if [[ "${ZWAVE_JS_SERVER}" = "yes" ]] && [[ -d ${ZWAVE_ADDONS_DIR} ]];
	then
		echo "Installing and configuring Zwave JS server, please be patient ..."
		# Unpack zwave-js-server, ts-node and other node modules
		tar zxvf ${ZWAVE_ADDONS_DIR}/src/node_modules.tar.gz -C /lib
		# Create symbolic link for ts-node
		ln -s /lib/node_modules/ts-node/dist/bin.js /usr/bin/ts-node

		# Copy sysconfig varaibles file
		cp -v ${ZWAVE_ADDONS_DIR}/config/sysconfig ${SYSCONFIG_DIR}/zwave-js-server
		# Copy systemd unit file for zwave-js-server
		cp -v ${ZWAVE_ADDONS_DIR}/systemd/zwave-js-server.service /etc/systemd/system/
		# Enable and start zwave-js-server if needed
		systemctl enable --now zwave-js-server.service 
	fi
else
# -----------------------------------------------------------------------------------
# Home-Assistant configuration for Others
# -----------------------------------------------------------------------------------
# Copy homeassistant configuration files
[[ -d $CONFIG_DIR/homeassistant ]] && \
	cd ${TMP_DIR} && rsync -av $CONFIG_DIR/homeassistant/ $HOME_ASSISTANT_CONFIG_DIR/
# Create homeassistant configuration directory if not existent
[[ -d $CONFIG_DIR/homeassistant ]] || mkdir -p $HOME_ASSISTANT_CONFIG_DIR
fi
#
# Create symbolic link to HASS config directory - needed by some tools that don't know about version info
ln -s -f $HOME_ASSISTANT_CONFIG_DIR /etc/homeassistant

# Change homeassistant config directory permissions
[[ -s $HOME_ASSISTANT_CONFIG_DIR ]] && \
	chown -R $HOME_ASSISTANT_USER:$HOME_ASSISTANT_USER $HOME_ASSISTANT_CONFIG_DIR

# TODO: Customize Home-Assistant i.e. secrets etc.....

# Copy home-assistant systemd file 
cat $SYSTEMD_DIR/home-assistant.service | \
	sed "s:"HOME_ASSISTANT_USER:${HOME_ASSISTANT_USER}:g \
	> /etc/systemd/system/home-assistant.service
# Enable and start home-assistant if needed
systemctl enable --now home-assistant.service
}

run_homeassistant_core_tests () {
HOME_ASSISTANT_NEW_VERS_STRING=$(echo $HOME_ASSISTANT_NEW_VERSION | sed "s/\.//g") 
HOME_ASSISTANT_CONFIG_DIR=/etc/homeassistant-${HOME_ASSISTANT_NEW_VERS_STRING}
#
# Tests
$(which hass) --version > /dev/null 2>&1
HASS_INSTALLED=$?
# Wait for hass to start
echo "Waiting for Home Assistant to be fully initiated and running, please wait ...."
sleep 15
$(which lsof) -t -i:8123 > /dev/null 2>&1
HASS_STARTED=$?
[[ -e ${HASS_CORE_INSTALLER_LOG} ]] && \
	awk '/Failed to Install/ {print $4}' ${HASS_CORE_INSTALLER_LOG}
HASS_PACKAGE_DEP_MISSING=$?
#
if [[ "${HASS_INSTALLED}" = "0" && "${HASS_STARTED}" = "0" ]];
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
#
elif [[ "${HASS_INSTALLED}" = "0" && "${HASS_STARTED}" != "0" ]];
then
clear
cat <<ET

#####################################################################
  Error:  Home Assistant Core installed but failed to start!
#####################################################################

Please check the following log file(s) to determine what went wrong:

${HOME_ASSISTANT_CONFIG_DIR}/home-assistant.log

ET
exit 255
fi

# Warn if there are uninstalled packages
if [[ "${HASS_INSTALLED}" = "0" && "${HASS_PACKAGE_DEP_MISSING}" = "0" ]];
then
cat <<ET

################################################################################
  Warning:  Installation of some required Home Assistant Core packages Failed!
################################################################################

Please install the following packages before restarting Home Assistant Core:
ET
#
[[ -e ${HASS_CORE_INSTALLER_LOG} ]] && \
	awk '/Failed to install/ {print $4}' ${HASS_CORE_INSTALLER_LOG} | sed '/^$/d'
fi

echo
}
