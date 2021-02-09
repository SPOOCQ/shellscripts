#!/bin/bash
##### NGINX Site manager
prep_conf ()
{
local default=$1
local name=$2
read input
#local input=$3
if [[ -n "$input" ]]; then
  value=$input
else
  value=$default
fi
echo ${name}=\"$value\" >> ngm.conf.tmp
}

##check if this system is run using init.d or systemd
check_initdsystemd ()
{
inits=`ps --no-headers -o comm 1`
if [[ "${inits}" == "init" ]]
    then
	defrestart="/etc/init.d/nginx restart"
elif [[ "${inits}" == "systemd" ]]
    then
	defrestart="systemctl nginx restart"
else
        defrestart=""
fi
}

setup_ngm ()
{
    rm ngm.conf.tmp > /dev/null 2> /dev/null
    check_initdsystemd
    echo "Setup"
    echo "Enter the path to your NGINX config folder (default: /etc/nginx)"
    prep_conf "/etc/nginx" "ngconf_path"
    echo "Enter the name of the directory containing the available configurations (default: sites-available)"
    prep_conf "sites-available" "av_sites"
    echo "Enter the name of the directory containing the enabled configurations (default: sites-enabled)"
    prep_conf "sites-enabled" "en_sites"
    echo "Enter the full path or command for the editor to use to edit the configuration files (default: nano)"
    prep_conf "nano" "editor"
    echo "Set the command to restart the NGINX webserver (default: ${defrestart})"
    prep_conf ${defrestart} "restart"
    mkdir ~/.ngm > /dev/null 2> /dev/null
    mv ngm.conf.tmp ~/.ngm/ngm.conf
    echo "Config was created."
    exit
}

## Building arrays 
arr_enable ()
{
ls $ngconf_path/$av_sites -I __*> /tmp/ng-av.ls
ls $ngconf_path/$en_sites -I __*> /tmp/ng-en.ls
mapfile -t gout < <(grep -Fxv -f /tmp/ng-en.ls /tmp/ng-av.ls)
rm /tmp/ng-av.ls
rm /tmp/ng-en.ls
}

arr_disable ()
{
mapfile -t gout < <(ls $ngconf_path/$en_sites -I __*)
}

arr_all ()
{
mapfile -t gout < <(ls $ngconf_path/$av_sites)
}


## Functions

createmenu ()
{
  local arrsize=$1
  local check='^[0-9q]+$'
  if [ "$arrsize" -gt 1 ] 
  then
     PS3="1-$arrsize or q to quit: "
   else
     PS3="1 or q to quit: "
    fi
  select option in "${@:2}"; do
   if ! [[ $REPLY =~ $check ]] ; then
   echo "error: Not a number" >&2; exit 1
   fi
   if [ "$REPLY" == "q" ];
    then
      echo "Exiting..."
      exit 0
      break;
    elif [ "$REPLY" -le $arrsize ];
    then
      #echo $option
      output=$option
      break;
    else
      echo "Incorrect Input: Select a number 1-$arrsize"
      exit 1
      break;
     fi
  done
}

testconfig ()
{
if nginx -t -q ; then
   echo 0
else
   echo 1
fi
}


getinput ()
{
  local arg=$1

  case $arg in
   e) arr_enable
      createmenu "${#gout[@]}" "${gout[@]}"
      enable $output
     ;;
   d) arr_disable
      createmenu "${#gout[@]}" "${gout[@]}"
      disable $output
      ;;
   m) arr_all
      createmenu "${#gout[@]}" "${gout[@]}"
      edit $output
      ;;
   r) restart
      ;;
   t) testconfig
      ;;
   * | h) printhelp
      ;;
   esac
}

enable ()
{
ln -s $ngconf_path/$av_sites/$output $ngconf_path/$en_sites/$output
result=$(testconfig)
if ! [ $result -eq 0 ] 
  then
      echo "ERROR! ROLLBACK!"
      rm $ngconf_path/$en_sites/$output
      echo "Please fix the error(s) in $output first"
  else
      echo "$output was enabled. Restarting nginx"
      $restart
  fi
}


printhelp ()
{
  echo "Usage:"
  echo "$0 m | e | d | r | t | h"
  echo "Commandline Paramaters:"
  echo -e "e \t Select a config to enable"
  echo -e "d \t Select a config to disable"
  echo -e "m \t Select a config to modify"
  echo -e "r \t Check config and restart NGINX"
  echo -e "t \t Test NGINX config"
}


restart ()
{
  result=$(testconfig)
  if [ $result -eq 0 ]
  then
  $restart
  else
      echo "Found errors in your config. Please fix them before restarting NGINX"
  fi
}


disable ()
{
 rm $ngconf_path/$en_sites/$output
 $result=$(testconfig)
 if ! [ $result -eq 0 ]
 then
     echo "ERROR! ROLLBACK!"
     ln -s $ngconf_path/$av_sites/$output $ngconf_path/$en_sites/$output
     echo "$output contains required settins (upstream?). Please fix this before disabling this config"
 else
    echo "$output was disabled. Restarting nginx"
    $restart
 fi
}


edit ()
{
  $editor $ngconf_path/$av_sites/$1
  if [ -f $ngconf_path/$en_sites/$1 ]
  then
      result=$(testconfig $1)
      if ! [ $result -eq 0 ]
      then
          echo "ERROR! MODIFICATION INVALID AND $1 is ENABLED!"
          echo "Please fix the syntax in $1 before restarting NGINX"
      else
          echo  "No error found. $1 is enabled - restarting NGINX to apply config"
          $restart
      fi
      else
          echo "$1 is not enabled. Unable to check syntax. Please try to enable to check for syntax errors"
      fi
}


## checking if called by root...

if [ "$EUID" -ne 0 ]
  then echo "Please run NGINX Site Manager as root or using sudo/doas"
  exit
fi

if [[ -d ~/.ngm ]]
then
   . ~/.ngm/ngm.conf
   getinput "${@}"
else
    echo "Configdirectory doesn't exist"
    until [ "$selection" = "0" ]; do
    echo ""
    echo "      1  -  Setup"
    echo "      0  -  Exit"
    echo ""
    echo -n "  Enter selection: "
    read selection
    echo ""
  case $selection in
    1 ) setup_ngm
        ;;
    0 ) exit ;;
    * ) incorrect_selection  ;;
  esac
done
fi
