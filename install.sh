#!/usr/bin/env bash
# ============================================================
#  Incognito Guard - Linux / macOS Installer
#  Run with: sudo bash install.sh
# ============================================================

EXT_ID="${1:-REPLACE_WITH_YOUR_EXTENSION_ID}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"

echo "============================================"
echo "  Incognito Guard - Setup ($OS)"
echo "============================================"

# ── Helper ────────────────────────────────────────────────
json_force_install() {
    echo "{\"ExtensionInstallForcelist\":[\"$EXT_ID;https://clients2.google.com/service/update2/crx\"]}"
}

# ── Chrome ────────────────────────────────────────────────
if [ "$OS" = "Linux" ]; then
    CHROME_POLICY="/etc/opt/chrome/policies/managed"
elif [ "$OS" = "Darwin" ]; then
    CHROME_POLICY="/Library/Application Support/Google/Chrome/policies/managed"
fi

if command -v google-chrome &>/dev/null || command -v google-chrome-stable &>/dev/null; then
    mkdir -p "$CHROME_POLICY"
    json_force_install > "$CHROME_POLICY/incognito_guard.json"
    echo "[OK] Chrome policy set"
else
    echo "[SKIP] Chrome not found"
fi

# ── Chromium ──────────────────────────────────────────────
if [ "$OS" = "Linux" ]; then
    CHROMIUM_POLICY="/etc/chromium/policies/managed"
    if command -v chromium-browser &>/dev/null || command -v chromium &>/dev/null; then
        mkdir -p "$CHROMIUM_POLICY"
        json_force_install > "$CHROMIUM_POLICY/incognito_guard.json"
        echo "[OK] Chromium policy set"
    fi
fi

# ── Brave ─────────────────────────────────────────────────
if [ "$OS" = "Linux" ]; then
    BRAVE_POLICY="/etc/opt/brave/policies/managed"
elif [ "$OS" = "Darwin" ]; then
    BRAVE_POLICY="/Library/Application Support/BraveSoftware/Brave-Browser/policies/managed"
fi

if command -v brave-browser &>/dev/null || command -v brave &>/dev/null; then
    mkdir -p "$BRAVE_POLICY"
    json_force_install > "$BRAVE_POLICY/incognito_guard.json"
    echo "[OK] Brave policy set"
else
    echo "[SKIP] Brave not found"
fi

# ── Firefox ───────────────────────────────────────────────
if [ "$OS" = "Linux" ]; then
    FF_PATHS=("/usr/lib/firefox" "/usr/lib64/firefox" "/snap/firefox/current/usr/lib/firefox")
elif [ "$OS" = "Darwin" ]; then
    FF_PATHS=("/Applications/Firefox.app/Contents/Resources")
fi

FF_POLICY='{
  "policies": {
    "ExtensionSettings": {
      "incognito-guard@yourname.com": {
        "installation_mode": "force_installed",
        "install_url": "https://addons.mozilla.org/firefox/downloads/your-ext.xpi"
      }
    }
  }
}'

for FF_PATH in "${FF_PATHS[@]}"; do
    if [ -d "$FF_PATH" ]; then
        mkdir -p "$FF_PATH/distribution"
        echo "$FF_POLICY" > "$FF_PATH/distribution/policies.json"
        echo "[OK] Firefox policy set at $FF_PATH"
        break
    fi
done

# ── Autostart guard.py ────────────────────────────────────
if [ "$OS" = "Linux" ]; then
    AUTOSTART_DIR="$HOME/.config/autostart"
    mkdir -p "$AUTOSTART_DIR"
    cat > "$AUTOSTART_DIR/incognito-guard.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Incognito Guard
Exec=python3 $SCRIPT_DIR/guard.py
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
    echo "[OK] Autostart entry created (Linux)"

elif [ "$OS" = "Darwin" ]; then
    PLIST="$HOME/Library/LaunchAgents/com.incognitoguard.plist"
    cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>             <string>com.incognitoguard</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/python3</string>
    <string>$SCRIPT_DIR/guard.py</string>
  </array>
  <key>RunAtLoad</key>         <true/>
  <key>KeepAlive</key>         <true/>
</dict>
</plist>
EOF
    launchctl load "$PLIST"
    echo "[OK] LaunchAgent created (macOS)"
fi

echo ""
echo "============================================"
echo "  Setup complete! Restart your browsers."
echo "  Default PIN: 1234  (change in Settings)"
echo "============================================"
