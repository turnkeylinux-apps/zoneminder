#!/bin/bash -e

CLARGUMENT=$1

#Check if Command Line Arguments Were Passed
#If given!
if [ ! -z $CLARGUMENT ]; then
#Write /etc/timezone with provided timezone
  echo $CLARGUMENT > /etc/timezone
#If not given execute dpkg-reconfigure tzdata
else
  dpkg-reconfigure tzdata
fi

# Assign variable TIMEZONE value of /etc/timezone
TIMEZONE=$( cat /etc/timezone )
#Default timezone line in /etc/php5/apache2/php.ini
sed -i '894s/.*/date.timezone = timezonesetnow/g' /etc/php5/apache2/php.ini
#Replace default value with user selected value
sed -i s$'\001'timezonesetnow$'\001'$TIMEZONE$'\001''g' /etc/php5/apache2/php.ini
