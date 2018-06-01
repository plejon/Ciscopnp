::cisco::eem::description "This policy bootstraps a switch with the switch uplink MAC addr"
::cisco::eem::event_register_appl tag timer sub_system 798 type 1 maxrun 18000
::cisco::eem::event_register_none tag none
::cisco::eem::trigger {
    ::cisco::eem::correlate event timer or event none
}

namespace import ::cisco::eem::*
namespace import ::cisco::lib::*

action_syslog msg "BOOTSTRAP: STARTING"

# Change below varaibles for your own env settings
set FTP "192.168.0.10"
set FTP_ios_path "cisco/ios/"
set FTP_conf_path "cisco/conf/"

if { [catch {cli_open} result] } {
    error $result $errorInfo
}

array set cli $result

if { [catch {cli_exec $cli(fd) "enable"} result] } {
    error $result $errorInfo
}


# ID PID, chassi ID
if { [catch {cli_exec $cli(fd) "show inventory"} result] } {
    error $result $errorInfo
}

action_syslog msg "BOOTSTRAP: Getting PID."
if { ! [regexp {PID:.(\S+)} $result -> pid] } {
    puts "ERROR: Failed to find PID in '$result'"
    exit 1
}
action_syslog msg "BOOTSTRAP: my PID is: '$pid'"

action_syslog msg "AUTOCONF: Getting SN"
if { ! [regexp {SN:.(\S+)} $result -> sn] } {
    puts "ERROR: Failed to find SN in '$result'"
    exit 1
}
action_syslog msg "AUTOCONF: my SN is: '$sn'"

# ID software version
if { [catch {cli_exec $cli(fd) "show version"} result] } {
    error $result $errorInfo
}

action_syslog msg "BOOTSTRAP: Getting Running Version"
if { ! [regexp {Version.(\S+),} $result -> vers] } {
    puts "ERROR: Failed to find version in $result"
    exit 1
}
action_syslog msg "BOOTSTRAP: Running Version is: '$vers'"


# ID system iage path location
action_syslog msg "BOOTSTRAP: Getting Image Path Location"
if { ! [regexp {System image file is "([^:]+:[^"]+)"} $result -> imagepath] } { ;#"
    puts "ERROR: Failed to find system image file in '$result'"
    exit 1
}
action_syslog msg "BOOTSTRAP: Image Path is: '$imagepath'"


# ID file and directory if image
set fstype {flash:}
set rawimagef [file tail $imagepath]
action_syslog msg "BOOTSTRAP: raw image file is: '$rawimagef'"
set imaged [file dirname $imagepath]
action_syslog msg "BOOTSTRAP: image dir is: '$imaged'"
regexp {([^:]+:)} $imagepath -> fstype


set image {}
set imagemd5 {}


# Change below for your prefered system ios files!
switch -regexp $pid {
  "C1111-8PLTEEA" {
    set image {c1100-universalk9_ias.16.08.01.SPA.bin}
    set imagemd5 {8dee04c886aa00ae6c794d7c65f52f9d}
  }
  "C892FSP-K9" {
    set image {c800-universalk9-mz.SPA.156-3.M3a.bin}
    set imagemd5 {cc72e6a2447db78b8871fb57638c98b2}
  }
  "ASR-920-12CZ-A" {
    set image {asr920-universalk9_npe.03.18.04.SP.156-2.SP4-ext.bin}
    set imagemd5 {a5661402bc74d427ccfbabfb41eb8cdd}
  }
  "ASR-920-24TZ-M" {
    set image {asr920-universalk9_npe.03.18.04.SP.156-2.SP4-ext.bin}
    set imagemd5 {a5661402bc74d427ccfbabfb41eb8cdd}
  }
  default {
    set image $rawimagef
    puts "ERROR: Failed to find the corresponding image to use with '$pid'"
  }
}
action_syslog msg "BOOTSTRAP: Image to use is: '$image' with md5: '$imagemd5'"


if { [string compare $image $rawimagef] == 0 } {
  action_syslog msg "BOOTSTRAP: The Switch is already on the correct image '$image'"
} else {
  action_syslog msg "BOOTSTRAP: The image needs to be upgraded from '$rawimagef' to '$image'"

  action_syslog msg "BOOTSTRAP: Downloading image: $FTP$FTP_ios_path$image"
  if { [catch {cli_exec $cli(fd) "copy $FTP$FTP_ios_path$image $fstype"} result] } {
    error $result $errorInfo
  }
  if { [regexp {bytes.copied.in} $result] } {
    action_syslog msg "BOOTSTRAP: Image Downloaded"
  } else {
    action_syslog msg "BOOTSTRAP: Unable to fetch the image '$image' at '$FTP$FTP_ios_path$image'"
    exit 1
  }

  # md5 check
  action_syslog msg "BOOTSTRAP: Computing MD5 Image '$fstype$image' with md5 '$imagemd5'"
  if { [catch {cli_exec $cli(fd) "verify /md5 $fstype$image $imagemd5"} result] } {
    error $result $errorInfo
  }

  #The output will show a 'Verified' if the md5 given in args match the result
  if { [regexp {Verified} $result] } {
    action_syslog msg "BOOTSTRAP: The md5 check is okay"
  } else {
    action_syslog msg "BOOTSTRAP: The md5 check failed - the image might be corrupted"
    puts "ERROR: The MD5 of the downloaded image is not correct!"
    exit 1
  }

  # Set the bootvar for the image
  action_syslog msg "BOOTSTRAP: Setting BOOTVAR"
  if { $image != {} } {
      if { [catch {cli_exec $cli(fd) "config terminal"} result] } {
        error $result $errorInfo
      }

      if { [catch {cli_exec $cli(fd) "boot system $fstype$image"} result] } {
        error $result $errorInfo
      }

      if { [catch {cli_exec $cli(fd) "end"} result] } {
        error $result $errorInfo
      }
  }
  action_syslog msg "BOOTSTRAP: BOOTVAR set"
}


# ID Mac addr on WAN interface (gi0/0/0 on ISR)
if { [catch {cli_exec $cli(fd) "show ip arp | i -"} result] } {
    error $result $errorInfo
}

if { ! [regexp {([0-9a-f]{4})\.([0-9a-f]{4})\.([0-9a-f]{4})} $result -> m1 m2 m3] } {
    puts "ERROR: Failed to find MAC in '$result'"
    exit 1
}

set MAC_ADDR [string toupper $m1$m2$m3]
action_syslog msg "BOOTSTRAP: uplink MAC is: '$MAC_ADDR'"


# Copy new config (serial_number.cfg) to starup-config
set conf $sn.cfg
action_syslog msg "BOOTSTRAP: Downloading the config for '$conf' at '$FTP$FTP_conf_path$conf'"

if { [catch {cli_exec $cli(fd) "copy $FTP$FTP_conf_path$conf startup-config"} result] } {
        error $result $errorInfo
}

# Did copy new config succeed?
if { [regexp {bytes.copied.in} $result] } {
  action_syslog msg "BOOTSTRAP: Config for '$conf' saved in startup-config"
} else {
  action_syslog msg "BOOTSTRAP: Unable to fetch the config for '$conf' at '$FTP$FTP_conf_path$conf'"
  action_syslog msg "BOOTSTRAP: Will power-cycle ZTP until config is located"
}

action_syslog msg "BOOTSTRAP COMPLETE: System reload in 10secs"

after 5000
catch {cli_close $cli(fd) $cli(tty_id)}
after 5000
action_reload
