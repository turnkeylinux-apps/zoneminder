ZoneMinder - Video Surveillance
===============================

ZoneMinder_ is a full-featured, open source, state-of-the-art video
surveillance software system. Monitor your home, office, or wherever you
want. Using off the shelf hardware with any camera, you can design a system
as large or as small as you need.

ZoneMinder appliance includes all the standard features in `TurnKey Core`_,
and on top of that:

- ZoneMinder configurations:

  - ZoneMinder installed from Debian backports apt repository.
  - ZoneMinder package pinned (security and convenience).

    **Security note**: Updates to ZoneMinder may require supervision so
    they **ARE NOT** configured to install automatically. See below for
    updating ZoneMinder.

- SSL support out of the box.
- `Adminer`_ administration frontend for MySQL (listening on port
  12322 - uses SSL).
- `Postfix`_ MTA (bound to localhost) to allow sending of email from web
  applications (e.g., password recovery).
- Webmin modules for configuring Apache2, PHP, MySQL and Postfix.

Supervised Manual Zoneminder Update
-----------------------------------

To upgrade to the latest Debian backports version of ZoneMinder from the
command line::

    apt-get update
    apt-get install zoneminder

Credentials *(passwords set at first boot)*
-------------------------------------------

-  Webmin, SSH, MySQL: username **root**
-  Adminer: username **adminer**
-  ZoneMinder credentials set during configuration

.. _ZoneMinder: https://zoneminder.com/
.. _TurnKey Core: https://www.turnkeylinux.org/core
.. _Adminer: https://www.adminer.org/
.. _Postfix: http://www.postfix.org/
