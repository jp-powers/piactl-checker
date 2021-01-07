# piactl-checker

The intent of this script is to connect to PIA using the piactl daemon CLI client, obtain the port provided for port forwarding, and load said port into Transmission. It's written so it can be run manually, on bootup, or via a cronjob.

# basic setup

My setup is an Ubuntu Server 20.04 VM, so no Xorg or anything. I'll provide some basic setup instructions but it's been a few months since I set this up originally and may need to add details about configuring the piactl client and other things, and some items may require different steps depending on the OS/distro you're on.


## PIA Install
First, download and install the PIA for Linux client from PIA: https://www.privateinternetaccess.com/pages/download. You can simple chmod +x the file and run it as a regular user.

After installing the PIA Linux, you can run the following command to allow it to run in the background:
>piactl background enable

This does not provide any autoconnection, hense the script, but it does allow the client to work without the GUI. Many settings, like protocol (OpenVPN or Wireguard), region selection, requesting port forwarding, etc. can be set from commands.

to login:
create a file with your username on one line and your password on another.
>chown root:root <that file>
>chmod 700 <that file>
The above two commands will help ensure other things/people on the device won't see the password without root access
>sudo piactl login <that file>

To see a selection of regions you can use:
>piactl get regions

This won't show you which support port forwarding, but does show you the exact name you need to use for the following. Note: As of writing (2021/01/07), all non-US servers support port forwarding according to the KB: https://www.privateinternetaccess.com/helpdesk/kb/articles/how-do-i-enable-port-forwarding-on-my-vpn

To set a region:
>piactl set region <region name from above>
  
You may need to also install transmission-remote if you don't already have it. I believe it's baked into the Ubuntu apt for transmission-cli or transmission-daemon, so the following should already be installed for you or have what you need if not:
> sudo apt install transmission-cli transmission-common transmission-daemon

## "Installing" the script

I don't really consider this installing anything, but sure, lets call it that.

>cp piactl-checker.sh /usr/local/bin
>sudo chmod 755 /usr/local/bin/piactl-checker.sh
>nano /usr/local/bin/piactl-checker.sh

Near the top of the file are a few lines to set variables: TRANSUSER, TRANSPASSWORD, TRANSHOST. Edit the variables as suites your transmission client setup. Note, I found that either due to how piactl works, how my transmission daemon is configured, or how I setup the routing tables on my VM I had to explicitly set TRANSHOST to the "in network" IP of my VM. Meaning, if my VM's local IP is 192.168.1.102, I would set TRANSHOST=192.168.1.102.

You should now be able to run the script manually by simply running piactl-checker.sh from the command line and it'll connect to PIA, and if needed open Transmission's port accordingly.

## Start on bootup
>cp piactl-checker.service /etc/systemd/system/
>sudo systemctl daemon-reload
>sudo systemctl enable piactl-checker

Now the script will run on bootup, so PIA will connect immediately.

## Run regularly to confirm PIA is still connected (makeshift keep-alive)
>sudo crontab -e
add the following to end of file:
>*/2 * * * * /usr/local/bin/piactl-checker.sh >/dev/null 2>&1
  
With this the script will run every 2 minutes to ensure it's still connected. I've found that piactld will allow the connection to go stale due to inactivity and it needs to be reconnected. The script is written to perform checks and should only attempt to reconnect if needed, and only attempt to update Transmissions' port if needed.

# TODO

From what I can tell this is working very well for my needs. Transmission is significantly faster with port forwarding actually working, and I believe this will be ... sustainable I guess would be the right word. Every guide I've found for setting up PIA/Transmission port forwarding is aged and PIA's changes over the years have broken them in various ways. This method utilizes the PIA provided client, so outside of them changing the commands to perform the necessary actions it should be quite stable and require little change. So, the script itself shouldn't need to change much but I'd like to do the following:

1. create an install script, that checks for all necessary applications and installs them if needed, walks you through configuring piactl, and will "generate" a version of the script with your necessary changes (TRANSUSER, TRANSPASS, etc.).
2. Add something to check for and update to new versions if possible.
3. Maybe try to figure out a better way to perform the "keep-alive" action.
