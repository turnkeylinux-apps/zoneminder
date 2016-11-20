#!/bin/bash -e

#Password Passed via argument in python subprocess call

#Assign Command Line Argument to Variable Password
password=$1

#Default ZM DB Password in zm.conf
sed -i 47s$'\001'.*$'\001''ZM_DB_PASS=defaultzmpassword'$'\001''g' /etc/zm/zm.conf
#Replace ZM DB Password in zm.conf
sed -i s$'\001'defaultzmpassword$'\001'$password$'\001''g' /etc/zm/zm.conf
#Default ZM DB Password in /usr/share/zoneminder/www/api/app/Config/database.php
sed -i 72s$'\001'.*$'\001'"'password' => 'defaultzmpassword',"$'\001''g' /usr/share/zoneminder/www/api/app/Config/database.php
#Replace ZM DB Password in /usr/share/zoneminder/www/api/app/Config/database.php
sed -i s$'\001'defaultzmpassword$'\001'$password$'\001''g' /usr/share/zoneminder/www/api/app/Config/database.php
