#!/usr/bin/python3
"""Set Zoneminder admin password

Option:
    --pass=     unless provided, will ask interactively
"""

import sys
import getopt

from libinithooks.dialog_wrapper import Dialog
from mysqlconf import MySQL


def usage(s=None):
    if s:
        print("Error:", s, file=sys.stderr)
    print("Syntax: %s [options]" % sys.argv[0], file=sys.stderr)
    print(__doc__, file=sys.stderr)
    sys.exit(1)

def main():
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], "h",
                                       ['help', 'pass='])
    except getopt.GetoptError as e:
        usage(e)

    password = ""
    for opt, val in opts:
        if opt in ('-h', '--help'):
            usage()
        elif opt == '--pass':
            password = val

    if not password:
        d = Dialog('TurnKey Linux - First boot configuration')
        password = d.get_password(
            "Zoneminder Password",
            "Enter new password for the Zoneminder 'admin' account.")

    m = MySQL()
    m.execute('UPDATE zm.Users SET Password=PASSWORD(%s) WHERE Username=\"admin\";', (password,))

if __name__ == "__main__":
    main()

