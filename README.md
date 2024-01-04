# piactl-checker

The intent of this script is to connect to PIA using the piactl daemon CLI client, obtain the port provided for port forwarding, and load said port into Transmission. It's written so it can be run manually, on bootup, or via a cronjob.

# basic setup

My setup is an Ubuntu Server 20.04 VM, so no Xorg or anything. I'll provide some basic setup instructions but it's been a few months since I set this up originally and may need to add details about configuring the piactl client and other things, and some items may require different steps depending on the OS/distro you're on.


## PIA Install
First, download and install the PIA for Linux client from PIA: https://www.privateinternetaccess.com/pages/download. You can simple chmod +x the file and run it as a regular user.

After installing the PIA Linux, you can run the following command to allow it to run in the background:

    piactl background enable

This does not provide any autoconnection, hense the script, but it does allow the client to work without the GUI. Many settings, like protocol (OpenVPN or Wireguard), region selection, requesting port forwarding, etc. can be set from commands.

to login:
create a file with your username on one line and your password on another.

    chown root:root <that file>
    chmod 700 <that file>
  
The above two commands will help ensure other things/people on the device won't see the password without root access

    sudo piactl login <that file>

To see a selection of regions you can use:

    piactl get regions

This won't show you which support port forwarding, but does show you the exact name you need to use for the following. Note: As of writing (2021/01/07), all non-US servers support port forwarding according to the KB: https://www.privateinternetaccess.com/helpdesk/kb/articles/how-do-i-enable-port-forwarding-on-my-vpn

To set a region:

    piactl set region <region name from above>
  
Now we need to enable piactl to request a port forward port from the region. To do this

    piactl set requestportforward true

You may need to also install transmission-remote if you don't already have it. I believe it's baked into the Ubuntu apt for transmission-cli or transmission-daemon, so the following should already be installed for you or have what you need if not:

    sudo apt install transmission-cli transmission-common transmission-daemon

## "Installing" the script

I don't really consider this installing anything, but sure, lets call it that.

    cp piactl-checker.sh /usr/local/bin
    sudo chmod 755 /usr/local/bin/piactl-checker.sh
    nano /usr/local/bin/piactl-checker.sh

Near the top of the file are a few lines to set variables: TRANSUSER, TRANSPASSWORD, TRANSHOST. Edit the variables as suites your transmission client setup. Note, I found that either due to how piactl works, how my transmission daemon is configured, or how I setup the routing tables on my VM I had to explicitly set TRANSHOST to the "in network" IP of my VM. Meaning, if my VM's local IP is 192.168.1.102, I would set `TRANSHOST=192.168.1.102`.

You should now be able to run the script manually by simply running piactl-checker.sh from the command line and it'll connect to PIA, and if needed open Transmission's port accordingly.

## Start on bootup

    cp piactl-checker.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable piactl-checker

Now the script will run on bootup, so PIA will connect immediately.

## Run regularly to confirm PIA is still connected (makeshift keep-alive)

    sudo crontab -e

add the following to end of file:

    */2 * * * * /usr/local/bin/piactl-checker.sh >/dev/null 2>&1
  
With this the script will run every 2 minutes to ensure it's still connected. I've found that piactld will allow the connection to go stale due to inactivity and it needs to be reconnected. The script is written to perform checks and should only attempt to reconnect if needed, and only attempt to update Transmissions' port if needed.

## Optional: Add route for accessibility via personal on network VPN

The following is purely optional and very dependent on your own home network setup. On my home network, I use a pfSense router with a Wireguard VPN tunnel. I have my phone, laptop, and a travel router setup as peers on this network. The idea is if I'm mobile the wireguard VPN is on and I'm routing all traffic from my phone, laptop, or the travel router through my home network. This gets me pfblocker based ad blocking, but also gets access to all my home network hosted devices.

The issue with the way we're setting up piactl is that it will take on an `ip route` scope that makes accessing this particular device more difficult. Essentially, the PIA VPN may now attempt to "capture" traffic that is otherwise "local network" traffic. This may be a unique case for myself, as I use 10.14.0.0 ranges of IP subnets for my home network, and PIA uses 10.0.0.0 ranges as well for their VPN subets. Either way, if you happen to have a similar issue (aka: everything works fine when physically on local network but when you are remote and VPN into your home network you can't connect to the machine running piactl), there's a simple fix.

What we'll be doing is adding a simple ip route to explicitly tell the machine "local traffic stays local." On my network, I can run the following command on the machine to establish this route:

    sudo ip route add 10.14.0.0/16 via 10.14.1.1 dev enp6s18 proto static onlink

Once run, I tested it by disconnecting my phone from my home wifi, letting the wireguard app connect to my VPN via 5G, and now when I attempt to connect to my VM running piactl it connects without issue. This is good for a test, but this ip route needs to be made each time the machine boots as well. This will depend on your OS, but on Debian 12 I edited the `/etc/network/interfaces` file. Identifying the iface for the ethernet adapter, simply adding an up `ip route add`, tabbed in once, with the full command we used above (dropping sudo this time) will create the rule when networking is established:

    iface enp6s18 inet dhcp
        up ip route add 10.14.0.0/16 via 10.14.1.1 dev enp6s18 proto static onlink

Then running `sudo systemctl restart networking.service` will restart networking, with this new rule. If you can still connect over your own VPN, you're good. On Ubuntu, instead of `/etc/network/interfaces`, you would need to change a file in `/etc/netplan`, the formatting is different for this so find an appropriate guide for assistance. In other distros it might be different as well. A simple Google search for "<distro name> <distro version> add ip route" should help. Including the distro version number will help ensure you're finding accurate guides as many distros have changed between different network management systems regularly.
# TODO

From what I can tell this is working very well for my needs. Transmission is significantly faster with port forwarding actually working, and I believe this will be ... sustainable I guess would be the right word. Every guide I've found for setting up PIA/Transmission port forwarding is aged and PIA's changes over the years have broken them in various ways. This method utilizes the PIA provided client, so outside of them changing the commands to perform the necessary actions it should be quite stable and require little change. So, the script itself shouldn't need to change much but I'd like to do the following:

1. create an install script, that checks for all necessary applications and installs them if needed, walks you through configuring piactl, and will "generate" a version of the script with your necessary changes (TRANSUSER, TRANSPASS, etc.).
1. Add something to check for and update to new versions if possible.
1. Maybe try to figure out a better way to perform the "keep-alive" action.
