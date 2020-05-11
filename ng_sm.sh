#!/bin/bash
##### NGINX Site manager

ngconf_path="/etc/nginx" # Your NGINX mainfolder
av_sites="sites-available" # Where your available configs are...
en_sites="sites-enabled" # Where your enabled configs are...
editor="nano" # Editor of choice
### Examples: "service nginx reload - nginx -s reload - /etc/init.d/nginx reload"
restart="rc-service nginx reload" # Command to restart NGINX



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


## and that's it...

getinput "${@}"
