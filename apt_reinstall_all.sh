### Small script to read the apt DB of installed packages
### and reinstall all of them.
### Has been quite useful on faulty imaged SD Cards in raspberry pis
#!/bin/bash
dpkg --get-selections > selection-tmp.log
awk '{ print $1 }' < selection-tmp.log > selection.log
rm selection-tmp.log
cat selection.log | xargs > installlist.log
apt-get install --reinstall < installlist.log -y
