#!/usr/bin/python
"""Set Timezone For System and ZoneMinder
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
        d = Dialog('Turnkey Linux First Boot Configuration')
        status = d.yesno("Set System Timezone For ZoneMinder Or Leave Default UTC","Selecting yes will launch tzselect from the command line")
        if status == 1:
   	    subprocess.call('bash /usr/lib/inithooks/bin/timezone.sh', shell=True)    
	else:
            d.msgbox("Your System Timezone and ZoneMinder Timezone will be UTC", "Select OK To Continue")        

if __name__ == "__main__":
    main()
