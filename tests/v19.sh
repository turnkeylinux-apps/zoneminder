#!/bin/bash -e

set -o pipefail

SOURCE_RECORD=/usr/local/share/turnkey-zoneminder/source
FIXTURE="tkl-v19-$RANDOM-$$"
MONITOR_ID=

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

trixie_provenance() {
    apt-cache madison zoneminder | awk -F '|' -v version="$1" '
        {
            package_version=$2
            source=$3
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", package_version)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", source)
            if (package_version == version && source ~ / (trixie|trixie-updates|trixie-security)\//) {
                print source
                exit
            }
        }
    '
}

cleanup() {
    if [ -n "$MONITOR_ID" ]; then
        mysql zm -e "DELETE FROM Monitors WHERE Id=$MONITOR_ID" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT HUP INT TERM

[ -n "${TKL_TEST_APP_PASS:-}" ] || fail "TKL_TEST_APP_PASS is required"
[ -f "$SOURCE_RECORD" ] || fail "source record is missing"
grep -qx 'package_source=Debian Trixie repositories' "$SOURCE_RECORD" || fail "unexpected package source"
grep -qx 'repository_suite=trixie' "$SOURCE_RECORD" || fail "unexpected repository suite"
grep -qx 'integrity=Debian archive signature verification' "$SOURCE_RECORD" || fail "unexpected integrity record"
installed=$(dpkg-query -W -f='${Version}' zoneminder)
recorded=$(sed -n 's/^installed_version=//p' "$SOURCE_RECORD")
[ -n "$installed" ] && [ "$installed" = "$recorded" ] || fail "installed package does not match source record"
installed_provenance=$(sed -n 's/^installed_provenance=//p' "$SOURCE_RECORD")
printf '%s\n' "$installed_provenance" |
    grep -Eq ' (trixie|trixie-updates|trixie-security)/' ||
    fail "source record has no Debian Trixie package provenance"

admin_hash=$(mysql -Nse "SELECT Password FROM zm.Users WHERE Username='admin'")
[ -n "$admin_hash" ] || fail "ZoneMinder admin account is missing"
ZM_ADMIN_PASS="$TKL_TEST_APP_PASS" ZM_ADMIN_HASH="$admin_hash" php -r '
    exit(password_verify(getenv("ZM_ADMIN_PASS"), getenv("ZM_ADMIN_HASH")) ? 0 : 1);
' || fail "firstboot ZoneMinder admin password does not match"
unset admin_hash

db_password=$(sed -n 's/^ZM_DB_PASS=//p' /etc/zm/zm.conf)
[ -n "$db_password" ] || fail "ZoneMinder database password is missing"
MYSQL_PWD="$db_password" mysql --user=zmuser -Nse \
    "SELECT Username FROM Users WHERE Username='admin'" zm |
    grep -qx admin || fail "ZoneMinder database credential does not work"
unset db_password

for service in apache2 mariadb zoneminder postfix; do
    systemctl -q is-enabled "$service" || fail "$service is not enabled"
    systemctl -q is-active "$service" || fail "$service is not active"
done
curl -kfsS https://127.0.0.1/ | grep -qi zoneminder || fail "HTTPS console did not render"

export FIXTURE
MONITOR_ID=$(python3 <<'PY'
import json
import os
import ssl
import urllib.parse
import urllib.request

context = ssl._create_unverified_context()
base = 'https://127.0.0.1/zm/api'

def request(path, data=None):
    body = urllib.parse.urlencode(data).encode() if data else None
    req = urllib.request.Request(base + path, data=body)
    with urllib.request.urlopen(req, context=context) as response:
        return json.load(response)

login = request('/host/login.json', {
    'user': 'admin',
    'pass': os.environ['TKL_TEST_APP_PASS'],
})
token = login['access_token']
created = request('/monitors.json', {
    'token': token,
    'Monitor[Name]': os.environ['FIXTURE'],
    'Monitor[Type]': 'Ffmpeg',
    'Monitor[Function]': 'None',
    'Monitor[Capturing]': 'None',
    'Monitor[Analysing]': 'None',
    'Monitor[Recording]': 'None',
    'Monitor[Enabled]': '0',
})
if created.get('message') != 'Saved':
    raise SystemExit('monitor creation failed: ' + repr(created))
monitors = request('/monitors.json?token=' + urllib.parse.quote(token))['monitors']
matches = [m['Monitor'] for m in monitors if m['Monitor']['Name'] == os.environ['FIXTURE']]
if len(matches) != 1:
    raise SystemExit('created monitor was not returned by API')
print(matches[0]['Id'])
PY
)
[ -n "$MONITOR_ID" ] || fail "monitor API did not return the fixture"
[ "$(mysql -Nse "SELECT Name FROM zm.Monitors WHERE Id=$MONITOR_ID")" = "$FIXTURE" ] ||
    fail "monitor was not persisted in MariaDB"

systemctl restart zoneminder
systemctl -q is-active zoneminder || fail "ZoneMinder failed after restart"
[ "$(mysql -Nse "SELECT Name FROM zm.Monitors WHERE Id=$MONITOR_ID")" = "$FIXTURE" ] ||
    fail "monitor did not survive restart"

update_check=$(zoneminder-update --check)
printf '%s\n' "$update_check" | grep -Fqx "installed=$installed" || fail "updater lost installed version"
candidate=$(printf '%s\n' "$update_check" | sed -n 's/^candidate=//p')
[ -n "$candidate" ] && [ "$candidate" != "(none)" ] || fail "updater found no Debian candidate"
candidate_provenance=$(printf '%s\n' "$update_check" | sed -n 's/^candidate_provenance=//p')
[ -n "$candidate_provenance" ] || fail "updater found no candidate provenance"
[ "$candidate_provenance" = "$(trixie_provenance "$candidate")" ] ||
    fail "candidate provenance is not a Debian Trixie package index"
printf '%s\n' "$update_check" | grep -qx 'channel=Debian Trixie repositories' || fail "updater channel is invalid"
printf '%s\n' "$update_check" | grep -qx 'metadata_signature_verification=apt-get-update-passed' || fail "updater metadata verification is missing"
printf '%s\n' "$update_check" | grep -Eq '^status=(up-to-date|update-available)$' || fail "updater status is invalid"
curl -kfsS https://127.0.0.1:12322/ >/dev/null || fail "Adminer HTTPS endpoint failed"
curl -kfsS https://127.0.0.1:12321/ >/dev/null || fail "Webmin HTTPS endpoint failed"

cleanup
MONITOR_ID=
trap - EXIT HUP INT TERM
[ "$(mysql -Nse "SELECT COUNT(*) FROM zm.Monitors WHERE Name='$FIXTURE'")" = 0 ] || fail "fixture cleanup failed"

if [ -n "${TKL_TEST_RESULT:-}" ]; then
    cat > "$TKL_TEST_RESULT" <<EOF
package_source=Debian Trixie repositories
installed_version=$installed
runtime_checks=HTTPS console, API admin login, disabled monitor create/read, MariaDB persistence, daemon restart, Adminer, Webmin, and cleanup passed
updater_command=zoneminder-update --check
updater_result=signed apt metadata accepted; verified installed version $installed from $installed_provenance and Debian candidate $candidate from $candidate_provenance
updater_channel=Debian Trixie repositories
integrity_evidence=apt-get update accepted Debian archive signatures and an eligible Trixie index
EOF
fi

echo "PASS: ZoneMinder HTTPS, API login, monitor lifecycle, database, services, and updater"
