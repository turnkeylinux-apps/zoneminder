#!/bin/bash -e

# Clear Screen
clear
# Call tzselct and send output to file /etc/timezone
tzselect > /etc/timezone
# Assign variable TIMEZONE value of /etc/timezone
TIMEZONE=$( cat /etc/timezone )
#Default timezone line in /etc/php5/apache2/php.ini
sed -i '894s/.*/date.timezone = timezonesetnow/g' /etc/php5/apache2/php.ini
#Replace default value with user selected value
sed -i s$'\001'timezonesetnow$'\001'$TIMEZONE$'\001''g' /etc/php5/apache2/php.ini
