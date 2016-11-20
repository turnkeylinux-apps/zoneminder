#!/usr/bin/python
"""Set zmuser database password
Option:
    --pass=     unless provided, will ask interactively
"""

import sys
import getopt
import inithooks_cache
import subprocess

from dialog_wrapper import Dialog
from mysqlconf import MySQL


def usage(s=None):
    if s:
        print >> sys.stderr, "Error:", s
    print >> sys.stderr, "Syntax: %s [options]" % sys.argv[0]
    print >> sys.stderr, __doc__
    sys.exit(1)

def main():
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], "h",
                                       ['help', 'pass='])
    except getopt.GetoptError, e:
        usage(e)

    password = ""
    email = ""
    for opt, val in opts:
        if opt in ('-h', '--help'):
            usage()
        elif opt == '--pass':
            password = val

    if not password:
        d = Dialog('TurnKey Linux - First boot configuration')
        password = d.get_password(
            "ZMUSER Password",
            "Enter new password for the ZMUSER database connection.")

    m = MySQL()
    m.execute('grant all on zm.* to zmuser@localhost identified by \"%s\";' % password)
    subprocess.call('/usr/lib/inithooks/bin/zoneminder.sh %s' % (str(password)), shell=True)

if __name__ == "__main__":
    main()

