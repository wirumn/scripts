#!/bin/zsh
# Uninstall NetBird (silent)

set -euo pipefail

APP="/Applications/NetBird.app"
APP_UI="/Applications/NetBird UI.app"
LAUNCHD_CLIENT="/Library/LaunchDaemons/io.netbird.client.plist"
LAUNCHD_MGT="/Library/LaunchDaemons/io.netbird.mgmt.plist"
LAUNCHD_NETBIRD="/Library/LaunchDaemons/netbird.plist"

log(){ /bin/echo "[$(date '+%F %T')] $*"; }

# Get console user (for cleaning user data)
consoleUser=$(/usr/bin/stat -f%Su /dev/console || true)
uid=$(/usr/bin/id -u "$consoleUser" 2>/dev/null || echo 0)
run_as_user(){ /bin/launchctl asuser "$uid" /usr/bin/sudo -u "$consoleUser" "$@"; }

log "Uninstalling NetBird…"

# 1) Stop NetBird cleanly via CLI (wherever it lives)
NETBIRD_CLI="$(command -v netbird || true)"
if [[ -n "$NETBIRD_CLI" && -x "$NETBIRD_CLI" ]]; then
    "$NETBIRD_CLI" down 2>/dev/null || true
    "$NETBIRD_CLI" service stop 2>/dev/null || true
    "$NETBIRD_CLI" service uninstall 2>/dev/null || true
fi

# 2) Quit UI + kill leftovers
if [[ "$consoleUser" != "root" && -n "$consoleUser" ]]; then
    run_as_user /usr/bin/osascript -e 'tell application "NetBird" to quit' 2>/dev/null || true
    run_as_user /usr/bin/osascript -e 'tell application "NetBird UI" to quit' 2>/dev/null || true
fi
/usr/bin/pkill -f "NetBird" 2>/dev/null || true
/usr/bin/pkill -f "netbird" 2>/dev/null || true

# 3) Boot out known job label
/bin/launchctl print system/netbird >/dev/null 2>&1 && /bin/launchctl bootout system/netbird 2>/dev/null || true

# 4) Unload and remove known LaunchDaemons
for plist in "$LAUNCHD_CLIENT" "$LAUNCHD_MGT" "$LAUNCHD_NETBIRD"; do
    if [[ -f "$plist" ]]; then
        /bin/launchctl bootout system "$plist" 2>/dev/null || /bin/launchctl unload "$plist" 2>/dev/null || true
        /bin/rm -f "$plist" 2>/dev/null || true
    fi
done

# 5) Remove app bundle(s)
for app in "$APP" "$APP_UI"; do
    [[ -d "$app" ]] && /bin/rm -rf "$app" 2>/dev/null || true
done

# 6) Remove CLI binary (common paths)
for bin in /usr/local/bin/netbird /usr/bin/netbird; do
    [[ -f "$bin" ]] && /bin/rm -f "$bin" 2>/dev/null || true
done

# 7) Remove system support files
/bin/rm -rf "/etc/netbird" 2>/dev/null || true
/bin/rm -rf "/var/lib/netbird" 2>/dev/null || true
/bin/rm -rf "/Library/Application Support/NetBird" 2>/dev/null || true
/bin/rm -rf "/Library/Logs/NetBird" 2>/dev/null || true
/usr/bin/find "/Library/PrivilegedHelperTools" -maxdepth 1 -name "*netbird*" -exec /bin/rm -f {} + 2>/dev/null || true

# 8) Remove user data for the logged-in user
if [[ "$consoleUser" != "root" && -n "$consoleUser" ]]; then
    UHOME=$(/usr/bin/dscl . -read "/Users/$consoleUser" NFSHomeDirectory 2>/dev/null | /usr/bin/awk '{print $2}')
    if [[ -d "$UHOME" ]]; then
        /bin/rm -rf "$UHOME/Library/Application Support/NetBird" 2>/dev/null || true
        /bin/rm -f  "$UHOME/Library/Preferences/io.netbird.client.plist" 2>/dev/null || true
        /bin/rm -f  "$UHOME/Library/Preferences/io.netbird.plist" 2>/dev/null || true
        /bin/rm -rf "$UHOME/Library/Logs/NetBird" 2>/dev/null || true
    fi
fi

# 9) Forget netbird pkg receipts
for pkg in $(/usr/sbin/pkgutil --pkgs | /usr/bin/grep -i -E 'netbird|io\.netbird' || true); do
    /usr/sbin/pkgutil --forget "$pkg" >/dev/null 2>&1 || true
done

log "NetBird has been removed."
exit 0
