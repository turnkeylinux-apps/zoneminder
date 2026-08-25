#!/usr/bin/python3
"""Set TIMEZONE and Edit Config Files
Option:
    --tz=     unless provided, will ask interactively
"""

import sys
import getopt
from pathlib import Path

import subprocess
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

    timezone = ""
    for opt, val in opts:
        if opt in ('-h', '--help'):
            usage()
        elif opt == '--tz':
            timezone = val

    if not timezone:
        timezone = 'Etc/UTC'
    if not Path('/usr/share/zoneinfo', timezone).is_file():
        usage("invalid timezone")
    php_ini = list(Path('/etc/php').glob('*/apache2/php.ini'))
    if len(php_ini) != 1:
        usage("unable to identify Apache PHP configuration")
    text = "date.timezone = " + timezone
    subprocess.run(['sed', '-i', 's|.*date.*timezone.*=.*|%s|g' % text,
                    str(php_ini[0])], check=True)
    subprocess.run(['service', 'apache2', 'restart'], check=True)
if __name__ == "__main__":
    main()
