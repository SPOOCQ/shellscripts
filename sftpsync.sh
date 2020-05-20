#!/bin/bash

#### A simple script to sync to folders over sftp using a timestamp file

timestamp=".last"
tempfile="/tmp/sftpsync.tmp"
count=0

trap "/bin/rm -f $tempfile" 0 1 15      # zap tempfile on exit &sigs

if [ $# -eq 0 ] ; then
  echo "Usage:"
  echo "$0 user@host { remotedir }" >&2
  exit 1
fi

user="$(echo $1 | cut -d@ -f1)"
server="$(echo $1 | cut -d@ -f2)"

if [ $# -gt 1 ] ; then
  echo "cd $2" >> $tempfile
fi

if [ ! -f $timestamp ] ; then
  for filename in *
  do 
    if [ -f "$filename" ] ; then
      echo "put -P \"$filename\"" >> $tempfile
      count=$(( $count + 1 ))
    fi
  done
else
  for filename in $(find . -newer $timestamp -type f -print)
  do 
    echo "put -P \"$filename\"" >> $tempfile
    count=$(( $count + 1 ))
  done
fi

if [ $count -eq 0 ] ; then
  echo "$0: Files are up to date" >&2
  exit 1
fi

echo "quit" >> $tempfile

echo "Found $count files in local folder missing on $server. Uploading..."

if ! sftp -b $tempfile "$user@$server" ; then
  echo "Finished..."
  touch $timestamp
fi

exit 0
