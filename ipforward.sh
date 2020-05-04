#!/bin/bash
localif="PLEASE_SET"


bold=$(tput bold)
normal=$(tput sgr0)
red=$(tput setaf 1)

if [ "$localif" == "PLEASE_SET" ] && [ "$1" != "-s" ] && [ "$1" != "--set" ]
then
	echo "${red}Please first set the interface by either using"
	echo "$0 -s | --set [DEVICENAME]"
	echo "or by editing $0 with a texteditor${normal}"
exit 1
fi



if [ -z ${1+x} ]
then
	echo "ERROR!"
	echo "Syntax:"
	echo "$0 [MODE] <OPTIONS>"
	echo "Use --help for full help"
else
	case "$1" in
	"-n"|"--new")
		if [ -z ${2+x} ] || [ -z ${3+x} ] || [ -z ${4+x} ]
		then
			echo "ERROR!"
			echo "Syntax:"
			echo "$0 -n | --new [Local Port] [Destination Port] [Destination Host] <proto> (tcp)"
		else
			lport=$2
			dport=$3
			dhost=$4
			if [ -z ${5+x} ]
			then
				proto="tcp"
			else
				proto="$5"
			fi
			iptables -A PREROUTING -t nat -i $localif -p $proto --dport $lport -j DNAT --to $dhost:$dport
			iptables -A FORWARD -p $proto -d $dhost --dport $lport -j ACCEPT
		fi
		;;

	"-d"|"--delete")
		if [ -z ${2+x} ] 
		then
			echo "ERROR!"
			echo "Syntax:"
			echo "$0 -d | --delete [LINE-NUMBER]"
		else
			# get local port as this is unique and write it to a variable
			export lnn=$(( $2 + 2 ))"p"
			lport=$(iptables -L PREROUTING -t nat --line-numbers | sed -n $lnn | tr -s ' ' | cut -f8 -d ' ' | cut -f2 -d ':')
			# get linenumber of FORWARD rule
			fln=$(iptables -L FORWARD --line-numbers | grep dpt:$lport | cut -f1 -d ' ')
			iptables -t nat -D PREROUTING $2
			iptables -D FORWARD $fln
		fi
		;;
	"-l"|"--list")
		iptables -L PREROUTING -t nat --line-numbers
		;;
	"-s"|"--set")
		replacement="0,/$localif/s//$2/g"
		sed -i $replacement $0
		;;
	"-h"|"--help")
		echo "Help:"
		echo "$0 [MODE] <OPTIONS>"
		echo ""
		echo "Create new forwarding rule:"
		echo "$0 -n | --new [LOCAL PORT] [DESTINATION PORT] [DESTINATION HOST] <PROTOCOL>"
		echo "Example: $0 -n 8080 80 192.168.10.1"
		echo ""
		echo "List Rules:"
		echo "$0 -l | --list"
		echo ""
		echo "Delete Rules:"
		echo "$0 -d | --delete [RULES#]"
		echo "Example: $0 -d 1"
		echo ""
		echo "Show Version:"
		echo "$0 -v | --version"
		;;
	"-v"|"--version")
		echo "IPForward Helper v.0.1"
		iptables --version
		;;
        *)
		echo "ERROR! UNKNOWN MODE!"
		echo "Syntax:"
		echo "$0 [MODE] <OPTIONS>"
	        echo "Use --help for full help"
	esac
fi
