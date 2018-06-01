# Ciscopnp

## This repo was made for ZTP Cisco devices using TCL and Event managers.

- Upgrades the device to desired ios version
- Finds the default DHCP interface MAC address
- Uses the Mac address to download correct config file. (can easily be modified to use serial number from "show inventory" output)
- Some cisco devices use "golden.cfg" after the reset button I pressed while booting. This file simply sets basic config for the device so I can me remotely accessed.

## Steps
- DHCP server gives the device tftp link to "bootstrap.cfg"
- the config is applied and the even managers starts
- It downloads "bootstrap.tcl" and "golden.cfg"
- the TCL script is executed
- Finds mac address, chassi serial number
- upgrades ios if needed
- downloads the desired config as "mac_address".cfg
- device reboots with new config file.


## Tests

I use this in live production for CPEs: ASR920, ISR1100 and 8xx series.
The "bootstrap.cfg" has two EEMs for downloading the TCL script. This is because the ASR920 needs some additional input when downloading TCl files.
This is just an ugly fix to get around this. All other models will just fail on this and go to next step in "bootstrap_init" EEM.


## Credits to:
- https://github.com/lodpp/cisco-catalyst-bootstrap
- https://supportforums.cisco.com/blog/12218591/automating-cisco-live-2014-san-francisco


## Question
Feel free to contact me if you have any questions.
per@lejon.org