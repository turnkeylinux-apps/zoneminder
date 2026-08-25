#!/bin/bash -e

set -o pipefail

SOURCE_RECORD=/usr/local/share/turnkey-zoneminder/source
FIXTURE="tkl-v19-$RANDOM-$$"
MONITOR_ID=

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

cleanup() {
    if [ -n "$MONITOR_ID" ]; then
        mysql zm -e "DELETE FROM Monitors WHERE Id=$MONITOR_ID" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT HUP INT TERM

[ -n "${TKL_TEST_APP_PASS:-}" ] || fail "TKL_TEST_APP_PASS is required"
[ -f "$SOURCE_RECORD" ] || fail "source record is missing"
grep -qx 'installed_version=1.38.4+trixie1' "$SOURCE_RECORD" || fail "unexpected version record"
grep -qx 'package_sha256=4828e9a0e86e2015701571cc443d37aae5e43fd4e270759c3f28463ae135f12e' "$SOURCE_RECORD" || fail "unexpected package digest"
grep -qx 'key_fingerprint=E148DCEBF90919B49C68F056A8C670C86F88B031' "$SOURCE_RECORD" || fail "unexpected signing key"

[ "$(dpkg-query -W -f='${Version}' zoneminder)" = 1.38.4+trixie1 ] || fail "unexpected package version"
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
printf '%s\n' "$update_check" | grep -qx 'installed=1.38.4+trixie1' || fail "updater lost installed version"
printf '%s\n' "$update_check" | grep -Eq '^candidate=1\.38\.' || fail "updater candidate is outside stable channel"
printf '%s\n' "$update_check" | grep -Eq '^status=(up-to-date|update-available)$' || fail "updater status is invalid"
curl -kfsS https://127.0.0.1:12322/ >/dev/null || fail "Adminer HTTPS endpoint failed"
curl -kfsS https://127.0.0.1:12321/ >/dev/null || fail "Webmin HTTPS endpoint failed"

cleanup
MONITOR_ID=
trap - EXIT HUP INT TERM
[ "$(mysql -Nse "SELECT COUNT(*) FROM zm.Monitors WHERE Name='$FIXTURE'")" = 0 ] || fail "fixture cleanup failed"

if [ -n "${TKL_TEST_RESULT:-}" ]; then
    cat > "$TKL_TEST_RESULT" <<EOF
package_source=official ZoneMinder release-1.38 Trixie apt repository
installed_version=1.38.4+trixie1
runtime_checks=HTTPS console, API admin login, disabled monitor create/read, MariaDB persistence, daemon restart, Adminer, Webmin, and cleanup passed
updater_command=zoneminder-update --check
updater_result=verified installed and candidate versions on the stable release-1.38 channel
updater_channel=official ZoneMinder release-1.38 Trixie apt repository
integrity_evidence=package SHA256 4828e9a0e86e2015701571cc443d37aae5e43fd4e270759c3f28463ae135f12e and signing key E148DCEBF90919B49C68F056A8C670C86F88B031
EOF
fi

echo "PASS: ZoneMinder HTTPS, API login, monitor lifecycle, database, services, and updater"
