ZoneMinder - Video Surveillance
==============================

A full-featured, open source, state-of-the-art video surveillance software 
system. Monitor your home, office, or wherever you want. Using off the 
shelf hardware with any camera, you can design a system as large or as small 
as you need.

ZoneMinder appliance includes all the standard features in `TurnKey Core`_, and on
top of that:

- SSL support out of the box.
- `Adminer`_ administration frontend for MySQL (listening on port
  12322 - uses SSL).
- `Postfix`_ MTA (bound to localhost) to allow sending of email from web
  applications (e.g., password recovery).
- Webmin modules for configuring Apache2, PHP, MySQL and Postfix.

Credentials *(passwords set at first boot)*
-------------------------------------------

-  Webmin, SSH, MySQL: username **root**
-  Adminer: username **adminer**
-  ZoneMinder credentials set during configuration
