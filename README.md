![alt text](hasslogo.png "HASS Core Installer")
# HASS Core Installer

## About 

HASS Core Installer is a simple tool used to install and upgrade Home Assistant Core on Linux systems including 
but not limited to the Raspberry Pi.  I created it to suppliment the official methods of installing Home Assistant 
which assume either a container setup or use of releases made by Linux distributions.  The later tend not to be 
updated quickly enough after each new release

HASS Core Installer is mainly used by our company i.e. Jambula Labs to quickly install and upgrade Home Assistant to 
the latest  releases.  This includes our custom Linux operating system i.e. [Jambula OS Linux](https://github.com/zikusooka/jambula-OS/) 

HASS Core Installer also supports offline installs and upgrades of Home Assistant.  Please note that in order for 
this to work, you must have pre-downloaded all the required python package dependencies and saved them in the 
python/archives directory

In case you don't know what it is, Home Assistant is an open-source home automation platform that focuses on 
privacy and local control. It is designed to be the central hub for managing and automating your smart home 
devices. Home Assistant integrates with a wide range of devices and services, allowing you to control your 
home environment from a single interface. It offers powerful automation features, notifications, and voice 
control, all while keeping your data private and secure.  You can read more about Home Assistant at:
https://home-assistant.io/


## Pre-requisites

You need to have access to a Linux machine  and be familiar with running commands on the Linux command line 
interface (CLI).


![alt text](images/console.png "HASS Core Installer")

## Installation

NOTE:  If you are using Jambula OS, you do not need to use this tool as it is already integrated with the OS images
       Simply run the setup tool which has an option to install Home Assistant Core

To install Home Assistant Core, follow these steps:

1. **Run the Installation Script**: Open a terminal and navigate to the directory where this tool was cloned to. 
Execute the following command to start the installation process:

    ```bash
    ./INSTALL.sh
    ```

## Upgrade

To upgrade Home Assistant Core, follow these steps:

    ```bash
    ./INSTALL.sh [NEW-VERSION] [OLD-VERSION]

    Example:
    ./INSTALL.sh  2024.12.0  2024.11.2

    ```

2. Wait for install program to complete
<b>IMPORTANT:  Make sure you are connected to the Internet </b>

3. **Configure Home Assistant**: After installation, you may need to configure Home Assistant to connect with your devices and set up automations. Refer to the [official documentation](https://www.home-assistant.io/docs/) for detailed setup and configuration instructions.
<b>HINT: Look in the scripts directory for some helper setup tools</b>

## Getting Started

Once installed, you can access the Home Assistant web interface by navigating to `http://localhost:8123` in your web browser. From there, you can start configuring your smart home devices and creating automations.

Enjoy!

Don't forget to thank the developers at Home Assistant project for the great work.  
For HASS support visit: [Home Assistant Community Forum](https://community.home-assistant.io/) 

## TO DO

## Support

   Your financial support can help sustain and improve this and other tools I have created.  
   Please consider contributing to my projects!  Check out the FUNDING file for details or contact me direct via 
   email using: joseph AT zikusooka.com
