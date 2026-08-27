#!/usr/bin/python3
"""Set Zoneminder admin password

The password is read from ZM_ADMIN_PASS or requested interactively.
"""

import sys
import getopt
import os
import subprocess

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
        opts, args = getopt.gnu_getopt(sys.argv[1:], "h", ['help'])
    except getopt.GetoptError as e:
        usage(e)

    password = os.environ.pop('ZM_ADMIN_PASS', '')
    for opt, val in opts:
        if opt in ('-h', '--help'):
            usage()
    if not password:
        d = Dialog('TurnKey Linux - First boot configuration')
        password = d.get_password(
            "Zoneminder Password",
            "Enter new password for the Zoneminder 'admin' account.")

    hash_env = os.environ.copy()
    hash_env['ZM_ADMIN_PASS'] = password
    password_hash = subprocess.run(
        ['php', '-r', 'echo password_hash(getenv("ZM_ADMIN_PASS"), PASSWORD_BCRYPT);'],
        env=hash_env, check=True, capture_output=True, text=True).stdout
    if not password_hash.startswith(('$2a$', '$2b$', '$2y$')):
        raise RuntimeError('PHP did not return a bcrypt password hash')
    m = MySQL()
    m.execute('UPDATE zm.Users SET Password=%s, APIEnabled=1 '
              'WHERE Username=\"admin\";',
              (password_hash,))

if __name__ == "__main__":
    main()
