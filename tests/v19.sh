#!/bin/bash -e

set -o pipefail

SOURCE_RECORD=/usr/local/share/turnkey-zoneminder/source
FIXTURE="tkl-v19-$RANDOM-$$"
MONITOR_ID=
TEST_TMPDIR=$(mktemp -d -t turnkey-zoneminder-v19.XXXXXX)

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

cleanup() {
    if [[ "$MONITOR_ID" =~ ^[0-9]+$ ]]; then
        mysql zm -e "DELETE FROM Monitor_Status WHERE MonitorId=$MONITOR_ID; DELETE FROM Monitors WHERE Id=$MONITOR_ID" >/dev/null 2>&1 || true
    fi
    rm -rf -- "$TEST_TMPDIR"
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
curl -kfsS https://127.0.0.1/ -o "$TEST_TMPDIR/landing-page"
grep -qi zoneminder "$TEST_TMPDIR/landing-page" || fail "HTTPS console did not render"
[ "$(zmdc.pl check)" = running ] || fail "ZoneMinder daemon controller is not healthy"
curl -kfsS -L \
    -c "$TEST_TMPDIR/web-cookie" \
    -b "$TEST_TMPDIR/web-cookie" \
    --data-urlencode action=login \
    --data-urlencode username=admin \
    --data-urlencode "password=$TKL_TEST_APP_PASS" \
    'https://127.0.0.1/zm/?view=login' \
    -o "$TEST_TMPDIR/web-login-response"
grep -q 'id="page"' "$TEST_TMPDIR/web-login-response" || fail "web login did not establish a session"
curl -kfsS -L \
    -c "$TEST_TMPDIR/web-cookie" \
    -b "$TEST_TMPDIR/web-cookie" \
    'https://127.0.0.1/zm/?view=options' \
    -o "$TEST_TMPDIR/web-options-response"
grep -q 'id="optionsContainer"' "$TEST_TMPDIR/web-options-response" || fail "authenticated web session failed"

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
    'Monitor[Device]': '',
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
monitor_id = str(matches[0]['Id'])
updated = request('/monitors/' + monitor_id + '.json', {
    'token': token,
    'Monitor[Enabled]': '1',
    'Monitor[Notes]': 'TurnKey v19 non-hardware control fixture',
})
if updated.get('message') != 'Saved':
    raise SystemExit('monitor control update failed: ' + repr(updated))
monitors = request('/monitors.json?token=' + urllib.parse.quote(token))['monitors']
matches = [m['Monitor'] for m in monitors if m['Monitor']['Name'] == os.environ['FIXTURE']]
if len(matches) != 1 or str(matches[0]['Enabled']) != '1':
    raise SystemExit('monitor control state was not returned by API')
print(monitor_id)
PY
)
[[ "$MONITOR_ID" =~ ^[0-9]+$ ]] || fail "monitor API did not return a numeric fixture id"
[ "$(mysql -Nse "SELECT Name FROM zm.Monitors WHERE Id=$MONITOR_ID")" = "$FIXTURE" ] ||
    fail "monitor was not persisted in MariaDB"
[ "$(mysql -Nse "SELECT Enabled FROM zm.Monitors WHERE Id=$MONITOR_ID")" = 1 ] ||
    fail "monitor control state was not persisted in MariaDB"

systemctl restart zoneminder
systemctl -q is-active zoneminder || fail "ZoneMinder failed after restart"
[ "$(zmdc.pl check)" = running ] || fail "ZoneMinder daemon controller failed after restart"
[ "$(mysql -Nse "SELECT Name FROM zm.Monitors WHERE Id=$MONITOR_ID")" = "$FIXTURE" ] ||
    fail "monitor did not survive restart"

export MONITOR_ID
python3 <<'PY'
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
monitor_id = urllib.parse.quote(os.environ['MONITOR_ID'])
delete_url = base + '/monitors/' + monitor_id + '.json?token=' + urllib.parse.quote(token)
delete_req = urllib.request.Request(delete_url, method='DELETE')
with urllib.request.urlopen(delete_req, context=context) as response:
    response.read()
monitors = request('/monitors.json?token=' + urllib.parse.quote(token))['monitors']
matches = [m['Monitor'] for m in monitors if m['Monitor']['Name'] == os.environ['FIXTURE']]
if matches:
    raise SystemExit('deleted monitor was still returned by API')
PY

update_check=$(zoneminder-update --check)
printf '%s\n' "$update_check" | grep -qx 'installed=1.38.4+trixie1' || fail "updater lost installed version"
printf '%s\n' "$update_check" | grep -Eq '^candidate=1\.38\.' || fail "updater candidate is outside stable channel"
printf '%s\n' "$update_check" | grep -Eq '^status=(up-to-date|update-available)$' || fail "updater status is invalid"
curl -kfsS https://127.0.0.1:12322/ >/dev/null || fail "Adminer HTTPS endpoint failed"
curl -kfsS https://127.0.0.1:12321/ >/dev/null || fail "Webmin HTTPS endpoint failed"

REMOVED_MONITOR_ID=$MONITOR_ID
MONITOR_ID=
cleanup
trap - EXIT HUP INT TERM
[ "$(mysql -Nse "SELECT COUNT(*) FROM zm.Monitors WHERE Name='$FIXTURE'")" = 0 ] || fail "fixture cleanup failed"
[ "$(mysql -Nse "SELECT COUNT(*) FROM zm.Monitor_Status WHERE MonitorId=$REMOVED_MONITOR_ID")" = 0 ] ||
    fail "monitor status cleanup failed"

if [ -n "${TKL_TEST_RESULT:-}" ]; then
    cat > "$TKL_TEST_RESULT" <<EOF
package_source=official ZoneMinder release-1.38 Trixie apt repository
installed_version=1.38.4+trixie1
runtime_checks=HTTPS web and API admin login, non-hardware monitor create/read/control/delete, MariaDB persistence, daemon restart, Adminer, Webmin, and cleanup passed
updater_command=zoneminder-update --check
updater_result=verified installed and candidate versions on the stable release-1.38 channel
updater_channel=official ZoneMinder release-1.38 Trixie apt repository
integrity_evidence=package SHA256 4828e9a0e86e2015701571cc443d37aae5e43fd4e270759c3f28463ae135f12e and signing key E148DCEBF90919B49C68F056A8C670C86F88B031
EOF
fi

echo "PASS: ZoneMinder web/API login, monitor lifecycle, database, services, and updater"
