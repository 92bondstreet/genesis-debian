#!/bin/sh
#
# Simple Firewall configuration.
#
# Author: Nicolargo
#
# chkconfig: 2345 9 91
# description: Activates/Deactivates the firewall at boot time
#
### BEGIN INIT INFO
# Provides:          firewall.sh
# Required-Start:    $syslog $network
# Required-Stop:     $syslog $network
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start firewall daemon at boot time
# Description:       Custom Firewall scrip.
### END INIT INFO

PATH=/bin:/sbin:/usr/bin:/usr/sbin

# Services that the system will offer to the network
TCP_SERVICES="22" # SSH
UDP_SERVICES=""
# Services the system will use from the network
REMOTE_TCP_SERVICES="80 443" # web browsing
REMOTE_UDP_SERVICES="53" # DNS
# FTP backups
# Allow backups to an external FTP
FTP_BACKUPS=""

if ! [ -x /sbin/iptables ]; then
	exit 0
fi

##########################
# Start the Firewall rules
##########################

fw_start () {

# Input traffic:
echo "[rules] input traffic..."
/sbin/iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Services
echo "[rules] services..."
if [ -n "$TCP_SERVICES" ] ; then
	for PORT in $TCP_SERVICES; do
		/sbin/iptables -A INPUT -p tcp --dport ${PORT} -j ACCEPT
	done
fi
if [ -n "$UDP_SERVICES" ] ; then
	for PORT in $UDP_SERVICES; do
		/sbin/iptables -A INPUT -p udp --dport ${PORT} -j ACCEPT
	done
fi

# Ftp backups
echo "[rules] ftp..."
if [ -n "$FTP_BACKUPS" ] ; then
	# The following two rules allow the inbound FTP connection
	/sbin/iptables -A INPUT -p tcp --sport ${FTP_BACKUPS} -m state --state ESTABLISHED -j ACCEPT
	/sbin/iptables -A OUTPUT -p tcp --dport ${FTP_BACKUPS} -m state --state NEW,ESTABLISHED -j ACCEPT
	# The next 2 lines allow active ftp connections
	#/sbin/iptables -A INPUT -p tcp --sport 20 -m state --state ESTABLISHED,RELATED -j ACCEPT
	#/sbin/iptables -A OUTPUT -p tcp --dport 20 -m state --state ESTABLISHED -j ACCEPT
	# These last two rules allow for passive transfers
	/sbin/iptables -A INPUT -p tcp --sport 1024: --dport 1024: -m state --state ESTABLISHED -j ACCEPT
	/sbin/iptables -A OUTPUT -p tcp --sport 1024: --dport 1024: -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
fi


# Remote testing
echo "[rules] remote testing..."
/sbin/iptables -A INPUT -p icmp -j ACCEPT
/sbin/iptables -A INPUT -i lo -j ACCEPT
/sbin/iptables -P INPUT DROP
/sbin/iptables -A INPUT -j LOG

# Output:
echo "[rules] output..."
/sbin/iptables -A OUTPUT -j ACCEPT -o lo
/sbin/iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# ICMP is permitted:
echo "[rules] ICMP..."
/sbin/iptables -A OUTPUT -p icmp -j ACCEPT

# NGinx and localhost
/sbin/iptables -A INPUT -i lo -s localhost -d localhost -j ACCEPT
/sbin/iptables -A OUTPUT -o lo -s localhost -d localhost -j ACCEPT
/sbin/iptables -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
/sbin/iptables -A INPUT  -p tcp --dport http -j ACCEPT

# So are security package updates:
# Note: You can hardcode the IP address here to prevent DNS spoofing
# and to setup the rules even if DNS does not work but then you
# will not "see" IP changes for this service:
echo "[rules] security package updates..."
/sbin/iptables -A OUTPUT -p tcp -d security.debian.org --dport 80 -j ACCEPT

# As well as the services we have defined:
if [ -n "$REMOTE_TCP_SERVICES" ] ; then
	for PORT in $REMOTE_TCP_SERVICES; do
		/sbin/iptables -A OUTPUT -p tcp --dport ${PORT} -j ACCEPT
	done
fi
if [ -n "$REMOTE_UDP_SERVICES" ] ; then
	for PORT in $REMOTE_UDP_SERVICES; do
		/sbin/iptables -A OUTPUT -p udp --dport ${PORT} -j ACCEPT
	done
fi

# All other connections are registered in syslog
echo "[rules] syslog..."
/sbin/iptables -A OUTPUT -j LOG
/sbin/iptables -A OUTPUT -j REJECT
/sbin/iptables -P OUTPUT DROP

# Other network protections
# (some will only work with some kernel versions)
echo "[rules] network..."
echo 1 > /proc/sys/net/ipv4/tcp_syncookies
echo 0 > /proc/sys/net/ipv4/ip_forward
echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts
echo 1 > /proc/sys/net/ipv4/conf/all/log_martians
echo 1 > /proc/sys/net/ipv4/icmp_ignore_bogus_error_responses
echo 1 > /proc/sys/net/ipv4/conf/all/rp_filter
echo 0 > /proc/sys/net/ipv4/conf/all/send_redirects
echo 0 > /proc/sys/net/ipv4/conf/all/accept_source_route

}

##########################
# Stop the Firewall rules
##########################

fw_stop () {
	/sbin/iptables -F
	/sbin/iptables -t nat -F
	/sbin/iptables -t mangle -F
	/sbin/iptables -P INPUT DROP
	/sbin/iptables -P FORWARD DROP
	/sbin/iptables -P OUTPUT ACCEPT

}

##########################
# Clear the Firewall rules
##########################

fw_clear () {
	/sbin/iptables -F
	/sbin/iptables -t nat -F
	/sbin/iptables -t mangle -F
	/sbin/iptables -P INPUT ACCEPT
	/sbin/iptables -P FORWARD ACCEPT
	/sbin/iptables -P OUTPUT ACCEPT
}

############################
# Restart the Firewall rules
############################

fw_restart () {
	fw_clear
	fw_start
}

##########################
# Test the Firewall rules
##########################

fw_save () {
	/sbin/iptables-save > /etc/iptables.backup
}

fw_restore () {
	if [ -e /etc/iptables.backup ]; then
		/sbin/iptables-restore < /etc/iptables.backup
	fi
}

fw_test () {
	fw_save
	fw_restart
	sleep 30
	fw_restore
}

case "$1" in
	start)
echo -n "Starting firewall..."
fw_start
echo "done."
;;
restart)
echo -n "Restarting firewall..."
fw_restart
echo "done."
;;
stop)
echo -n "Stopping firewall..."
fw_stop
echo "done."
;;
clear)
echo -n "Clearing firewall rules..."
fw_clear
echo "done."
;;
test)
echo -n "Test Firewall rules..."
echo -n "Previous configuration will be restore in 30 seconds"
fw_test
echo -n "Configuration as been restored"
;;
*)
echo "Usage: $0 {start|stop|restart|clear|test}"
echo "Be aware that stop drop all incoming/outgoing traffic !!!"
exit 1
;;
esac
exit 0
