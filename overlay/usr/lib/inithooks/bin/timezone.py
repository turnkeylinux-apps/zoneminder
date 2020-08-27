#!/usr/bin/python3
"""Set TIMEZONE and Edit Config Files
Option:
    --tz=     unless provided, will ask interactively
"""

import sys
import getopt

import subprocess
from dialog_wrapper import Dialog

def usage(s=None):
    if s:
        print("Error:", s, file=sys.stderr)
    print("Syntax: %s [options]" % sys.argv[0], file=sys.stderr)
    print(__doc__, file=sys.stderr)
    sys.exit(1)

def main():
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], "h",
                                       ['help', 'tz='])
    except getopt.GetoptError as e:
        usage(e)

    password = ""
    for opt, val in opts:
        if opt in ('-h', '--help'):
            usage()
        elif opt == '--tz':
            timezone = val

    if not timezone:
        timezone = 'Etc/UTC'
    text = "date.timezone = " + timezone
    subprocess.run(['sed', '-i', 's|.*date.*timezone.*=.*|%s|g' % text, '/etc/php/7.3/apache2/php.ini'])    
    subprocess.run(['service', 'apache2', 'restart'])
if __name__ == "__main__":
    main()
