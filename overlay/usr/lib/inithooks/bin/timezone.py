#!/usr/bin/python
"""Set TIMEZONE and Edit Config Files
Option:
    --tz=     unless provided, will ask interactively
"""

import sys
import getopt

from executil import system
from dialog_wrapper import Dialog

def usage(s=None):
    if s:
        print >> sys.stderr, "Error:", s
    print >> sys.stderr, "Syntax: %s [options]" % sys.argv[0]
    print >> sys.stderr, __doc__
    sys.exit(1)

def main():
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], "h",
                                       ['help', 'tz='])
    except getopt.GetoptError, e:
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
    system('sed', '-i', 's|.*date.*timezone.*=.*|%s|g' % text, '/etc/php/7.0/apache2/php.ini')    
    system('service', 'apache2', 'restart')
if __name__ == "__main__":
    main()
