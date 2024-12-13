#!/bin/bash

check_if_internet_is_up () {
ping -c 1 -W 2 8.8.4.4 > /dev/null 2>&1
INTERNET_ALIVE=$?
}

python3_module_local_download () {
PYTHON_MODULE=$1
PYTHON_PKG_FORMAT=$2
PYTHON_PKG=$(echo $PYTHON_MODULE | cut -d'=' -f1)
PYTHON_DOWNLOADS_DIR=$TMP_DIR/python3_deps.${PYTHON_MODULE}

case $PYTHON_PKG_FORMAT in
wheel)
pip3 --disable-pip-version-check download --prefer-binary -d $PYTHON_DOWNLOADS_DIR $PYTHON_MODULE
;;

source)
pip3 --disable-pip-version-check download --no-binary :all: --only-binary none -d $PYTHON_DOWNLOADS_DIR $PYTHON_MODULE
;;

all|both)
pip3 --disable-pip-version-check download --prefer-binary -d $PYTHON_DOWNLOADS_DIR $PYTHON_MODULE
pip3 --disable-pip-version-check download --no-binary :all: --only-binary none -d $PYTHON_DOWNLOADS_DIR $PYTHON_MODULE
;;

*)
pip3 --disable-pip-version-check download --prefer-binary -d $PYTHON_DOWNLOADS_DIR $PYTHON_MODULE
;;
esac
}

python3_module_local_install () {
PYTHON_MODULE=$1
# Remove pips cache directory - if left causes all sorts of issues
[[ -d $HOME/.cache/pip ]] && rm -rf $HOME/.cache/pip
# Install using locally stored package
pip3 --log $BUILD_LOG install --no-cache-dir --upgrade --upgrade-strategy eager --no-index --find-links $PYTHON_ARCHIVES_DIR $PYTHON_MODULE
}

python3_venv_destroy () {
# Delete python3 virtual environment for [PACKAGE]
# Usage: python3_venv_destroy [PACKAGE] [VERSION_STRING]
#   e.g. python3_venv_destroy homeassistant 202173
VENV_PACKAGE=$1
VENV_PACKAGE_VERSION_STRING=$2

# Delete virtual environment
if [[ "x$VENV_PACKAGE_VERSION_STRING" != "x" ]] && [[ -d $PYTHON3_VENV_ROOT_DIR/$VENV_PACKAGE-${VENV_PACKAGE_VERSION_STRING} ]];
then
echo "Destroying previous virtual environment [$VENV_PACKAGE-${VENV_PACKAGE_VERSION_STRING}], please be patient ..."
rm -rf $PYTHON3_VENV_ROOT_DIR/$VENV_PACKAGE-${VENV_PACKAGE_VERSION_STRING}
elif [[ -d $PYTHON3_VENV_ROOT_DIR/$VENV_PACKAGE ]];
then
echo "Destroying previous virtual environment [$VENV_PACKAGE], please be patient ..."
rm -rf $PYTHON3_VENV_ROOT_DIR/$VENV_PACKAGE
else
echo "No previous virtual installations found, proceeding ..." 
fi
}

python3_venv_create () {
# Create python3 virtual environment for [PACKAGE]
# Usage: python3_venv_create [PYTHON3_BINARY] [PACKAGE] [USER]
#   e.g. python3_venv_create python3.8 homeassistant jambula
VENV_PYTHON3_BINARY=$1
VENV_PACKAGE=$2
VENV_USER=$3
VENV_HOME_DIR=$PYTHON3_VENV_ROOT_DIR/$VENV_PACKAGE
VENV_BIN_DIR=$VENV_HOME_DIR/bin
VENV_SITE_DIR=$VENV_HOME_DIR/lib/$VENV_PYTHON3_BINARY/site-packages
PYTHON3_CMD=$VENV_BIN_DIR/python3
PIP3_CMD=$VENV_BIN_DIR/pip3
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
mkdir -p $VENV_HOME_DIR
# Give user ownership of virtual environment directory
chown -R $VENV_USER:$VENV_USER $VENV_HOME_DIR
#
# Switch to virtual environment directory
cd $VENV_HOME_DIR
#
# Create virtual environment
echo "Creating new virtual environment [$VENV_PACKAGE], please be patient ..."
sudo -u $VENV_USER $(which $VENV_PYTHON3_BINARY) -m venv .
# Activate virtual environment
echo "Activating virtual environment [$VENV_PACKAGE], please be patient ..."
source bin/activate

# Upgrade key packages for use in virtual environment
for PACKAGE in \
pip \
setuptools \
wheel
do
# Install packages when Internet is available
check_if_internet_is_up
#
if [[ "${INTERNET_ALIVE}" = "0" ]];
then
	$PIP3_CMD install --prefer-binary --no-cache-dir --upgrade --upgrade-strategy only-if-needed $PACKAGE
else
	$PIP3_CMD install --prefer-binary --no-cache-dir --upgrade --upgrade-strategy only-if-needed --no-index --find-links $PYTHON_ARCHIVES_DIR $PACKAGE
fi
done
# Export virtual environment variables
export VENV_BIN_DIR PYTHON3_CMD PIP3_CMD
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
python3_venv_destroy home-assistant-core $HOME_ASSISTANT_OLD_VERS_STRING

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

homeassistant_core_install () {
# Set the home-assistant core tag plus other variables to be used
HOME_ASSISTANT_TAG="$1"
HOME_ASSISTANT_PYTHON3_BINARY="$2"
HOME_ASSISTANT_RELEASES_REPO="https://github.com/home-assistant/core/archive/refs/tags"
#
# Set version string
HOME_ASSISTANT_NEW_VERS_STRING=$(echo $HOME_ASSISTANT_TAG | sed "s/\.//g")
export HOME_ASSISTANT_NEW_VERS_STRING
#
# Set python binary version
if [[ "x$HOME_ASSISTANT_PYTHON3_BINARY" != "x" ]];
then
HOME_ASSISTANT_PYTHON3_BINARY=$HOME_ASSISTANT_PYTHON3_BINARY
else
HOME_ASSISTANT_PYTHON3_BINARY=$(python3 --version | rev | cut -d '.' -f2- | rev | sed 's: ::g' | tr '[:upper:]' '[:lower:]')
fi

HOME_ASSISTANT_INSTALL_PKG_CONSTRAINTS_FILE=$INSTALL_SRC_DIR/home-assistant-core-${HOME_ASSISTANT_NEW_VERS_STRING}/homeassistant/package_constraints.txt

# Create python 3 virtual environment for home-assistant-core using python version specified above
python3_venv_create $HOME_ASSISTANT_PYTHON3_BINARY home-assistant-core-$HOME_ASSISTANT_NEW_VERS_STRING jambula

# Forcefully add pre-packaged dependencies that are required to install Home-Assistant on Arm64 boards
# This is a temporary workaround as many aarch64 are still being built at this time
PYTHON_VERS=$(python3 -V | awk '{print $2}' | cut -d '.' -f1-2 | sed 's:\.::')
if [[ "${MACHINE_ARCH}" = "aarch64" ]];
then
for PACKAGE in \
	ciso8601-2.3.0 \
	netifaces-0.11.0
do
if [[ -e "$PYTHON_ARCHIVES_DIR/${PACKAGE}-python${PYTHON_VERS}-aarch64.tar.bz2" ]];
then
	tar jxvf $PYTHON_ARCHIVES_DIR/${PACKAGE}-python${PYTHON_VERS}-aarch64.tar.bz2 \
		-C $PYTHON3_VENV_ROOT_DIR/home-assistant-core-$HOME_ASSISTANT_NEW_VERS_STRING/
else
	echo "Warning: The package ${PACKAGE}-python${PYTHON_VERS}-aarch64.tar.bz2 was not found, please download
	it manually and place it under the directory: $PYTHON_ARCHIVES_DIR/"
fi
done
#
#
# Packages that fail to build wheels
for PACKAGE in pyspeex-noise
do
	$PIP3_CMD install --prefer-binary --no-cache-dir --upgrade \
		--upgrade-strategy only-if-needed --no-index \
		--find-links $PYTHON_ARCHIVES_DIR ${PACKAGE} || \
		echo "Warning: Failed to install ${PACKAGE}"
done
fi

# Notice: Installing home-assistant-core [version]
clear
cat <<ET

Starting installation of Home Assistant Core [${HOME_ASSISTANT_TAG}], please be patient ...

ET
sleep 5

# Check for Internet connectivity
check_if_internet_is_up
#
# Prepare home-assistant-core sources
if [[ -f "${SRC_DIR}/core-${HOME_ASSISTANT_TAG}.tar.gz" ]]
then
	# Unpack archive of Home-Assistant Core locally
	cd ${INSTALL_SRC_DIR} && tar zxvf ${SRC_DIR}/core-${HOME_ASSISTANT_TAG}.tar.gz \
		--one-top-level=home-assistant-core-${HOME_ASSISTANT_NEW_VERS_STRING} \
		--strip-components=1 

elif [[ "${INTERNET_ALIVE}" = "0" ]];
then
	# Fetch archive of Home-Assistant Core from upstream
	[[ -s ${TMP_DIR}/home-assistant-core-${HOME_ASSISTANT_NEW_VERS_STRING}.tar.gz ]] || \
		wget --no-check-certificate -c -O ${TMP_DIR}/home-assistant-core-${HOME_ASSISTANT_NEW_VERS_STRING}.tar.gz ${HOME_ASSISTANT_RELEASES_REPO}/${HOME_ASSISTANT_TAG}.tar.gz 
	# Unpack archive of Home-Assistant Core locally
	cd ${INSTALL_SRC_DIR} && tar zxvf ${TMP_DIR}/home-assistant-core-${HOME_ASSISTANT_NEW_VERS_STRING}.tar.gz \
		--one-top-level=home-assistant-core-${HOME_ASSISTANT_NEW_VERS_STRING} \
		--strip-components=1 

elif [[ "${INTERNET_ALIVE}" != "0" ]];
then
	echo "Installation of Home-Assistant-Core failed. Unable to not connect to the Internet and package the archive [core-${HOME_ASSISTANT_NEW_VERS_STRING}.tar.gz"

else
	echo "Installation of Home-Assistant-Core failed.  The archive [core-${HOME_ASSISTANT_NEW_VERS_STRING}.tar.gz] is not available"
exit 1
fi

# Update pyproject.toml file
sed -i "s:ciso8601==2.3.1:ciso8601==2.3.0:g" $INSTALL_SRC_DIR/home-assistant-core-${HOME_ASSISTANT_NEW_VERS_STRING}/pyproject.toml

# Change to sources directory
cd $INSTALL_SRC_DIR/home-assistant-core-${HOME_ASSISTANT_NEW_VERS_STRING}
#
# Build translation files
$PYTHON3_CMD -m script.translations develop --all

# Install source files based on Internet availability
if [[ "${INTERNET_ALIVE}" = "0" ]];
then
	# Install dependencies needed by Home-Assistant during installation if Internet is active
	grep -v -e "^#" -e 1000000000 ${HOME_ASSISTANT_INSTALL_PKG_CONSTRAINTS_FILE} | sed "/^$/d" | \
		while read PACKAGE;
		do
			# Download package and save it in archive directory
			$PIP3_CMD download --prefer-binary -d ${PYTHON_ARCHIVES_DIR} ${PACKAGE}
			# 
			# Install package from archives directory
			$PIP3_CMD install --prefer-binary --no-cache-dir --upgrade \
				--upgrade-strategy only-if-needed \
				--find-links $PYTHON_ARCHIVES_DIR ${PACKAGE} || \
				echo "Warning: Failed to install $PACKAGE"
		done

	# Install Home-Assistant Core when Internet is available
	$PIP3_CMD install --prefer-binary --no-cache-dir --upgrade --upgrade-strategy only-if-needed \
		--find-links $PYTHON_ARCHIVES_DIR .

	# Install other packages needed after install and when running Home-Assistant - Internet is avaialable
	[[ -e $HASS_INSTALL_REQUIREMENTS_FILE ]] && $PIP3_CMD install --prefer-binary --no-cache-dir \
		--upgrade --upgrade-strategy only-if-needed -r $HASS_INSTALL_REQUIREMENTS_FILE

else
	# Install dependencies needed by Home-Assistant during installation there's NO if Internet
	grep -v -e "^#" -e 1000000000 ${HOME_ASSISTANT_INSTALL_PKG_CONSTRAINTS_FILE} | sed "/^$/d" | \
		while read PACKAGE;
		do
		$PIP3_CMD install --prefer-binary --no-cache-dir --upgrade \
			--upgrade-strategy only-if-needed --no-index \
			--find-links $PYTHON_ARCHIVES_DIR ${PACKAGE} || \
			echo "Warning: Failed to install ${PACKAGE}"
		done 

	# Install Home-Assistant Core when Internet is NOT available
	$PIP3_CMD install --prefer-binary --no-cache-dir --upgrade --upgrade-strategy only-if-needed \
		--no-index --find-links $PYTHON_ARCHIVES_DIR .

	# Install other packages needed after install and when running Home-Assistant - Internet NOT avaialable
	[[ -e $HASS_INSTALL_REQUIREMENTS_FILE ]] && $PIP3_CMD install --prefer-binary --no-cache-dir \
		--upgrade --upgrade-strategy only-if-needed --no-index --find-links $PYTHON_ARCHIVES_DIR \
		-r $HASS_INSTALL_REQUIREMENTS_FILE
fi

# Create symbolic links
[[ -x /usr/bin/hass-${HOME_ASSISTANT_NEW_VERS_STRING} ]] || \
	ln -s $VENV_BIN_DIR/hass /usr/bin/hass-${HOME_ASSISTANT_NEW_VERS_STRING}
[[ -x /usr/bin/hass-${HOME_ASSISTANT_NEW_VERS_STRING} ]] && \
	ln -s -f /usr/bin/hass-${HOME_ASSISTANT_NEW_VERS_STRING} /usr/bin/hass

# Create environment variables file for home-assistant-core
cat > $SYSCONFIG_DIR/home-assistant-core <<ET
HOME_ASSISTANT_NEW_VERS_STRING="${HOME_ASSISTANT_NEW_VERS_STRING}"
HOME_ASSISTANT_CMD="/usr/bin/hass-\${HOME_ASSISTANT_NEW_VERS_STRING}"
HOME_ASSISTANT_CONFIG_DIR=/etc/homeassistant-\${HOME_ASSISTANT_NEW_VERS_STRING}
HOME_ASSISTANT_USER=${HOME_ASSISTANT_USER}
HOME_ASSISTANT_PATH="/srv/jambula/home-assistant-core-2024100/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/hass/.local/bin"
PATH=\${HOME_ASSISTANT_PATH}              
ET

# Remove sources in install directory to save on space
[[ -d $INSTALL_SRC_DIR/home-assistant-core-${HOME_ASSISTANT_NEW_VERS_STRING} ]] && \
	rm -rf $INSTALL_SRC_DIR/home-assistant-core-${HOME_ASSISTANT_NEW_VERS_STRING}
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

# Give HASS user permissions to install packages in Python virtual environment
chown -R $HOME_ASSISTANT_USER $VENV_HOME_DIR

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

# Copy homeassistant configuration files
[[ -d $HASS_ADDONS_DIR/config/homeassistant ]] && \
	cd ${TMP_DIR} && rsync -av $HASS_ADDONS_DIR/config/homeassistant/ $HOME_ASSISTANT_CONFIG_DIR/
#
# Copy udev rules 4 home automation controllers - ttyUSB*
cp -v $HASS_ADDONS_DIR/udev/90-jambula-usb-zwave.rules /etc/udev/rules.d
# Reload udev
/usr/bin/udevadm control --reload && udevadm trigger --action=add

# Copy jambulatv-homeassistant-secrets script, if it does not exist in bin directory
[ -e $HASS_ADDONS_DIR/bin/jambula-homeassistant-secrets ] && \
	cp -v $HASS_ADDONS_DIR/bin/jambula-homeassistant-secrets /usr/bin/
# Make script executable
chmod 755 /usr/bin/jambula-homeassistant-secrets

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
