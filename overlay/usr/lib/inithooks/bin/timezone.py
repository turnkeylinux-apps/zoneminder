#!/usr/bin/python
"""Set Timezone for ZoneMinder and System
Option:
    --pass=     unless provided, will ask interactively
"""

import sys
import getopt
import inithooks_cache
import subprocess

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

    timezone = ""
    for opt, val in opts:
        if opt in ('-h', '--help'):
            usage()
        elif opt == '--tz':
            timezone = val
    if not timezone:
        subprocess.call('/usr/lib/inithooks/bin/timezone.sh', shell=True)
    else:    
        subprocess.call('/usr/lib/inithooks/bin/timezone.sh %s' % (str(timezone)), shell=True)

if __name__ == "__main__":
    main()

