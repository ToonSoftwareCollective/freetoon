#!/bin/sh
# freetoon.sh - Install FreeToon if not present, switch to FreeToon from stock qt-gui,
# or uninstall FreeToon and revert cleanly to stock qt-gui.
# Compatible with FreeToon 1.0.0 (Toon 1 and Toon 2).
# Can be run directly from shell or kicked off by TSC / the Freetoon QML app.

set -e

# Prevent being killed if parent process (e.g. qt-gui / TSC child) exits
trap '' HUP TERM INT

# Decouple from parent process group / session so init killing startqt does not kill this script
if [ "${SWITCH_DETACHED:-0}" != "1" ]; then
    export SWITCH_DETACHED=1
    if command -v setsid >/dev/null 2>&1; then
        exec setsid "$0" "$@"
    elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | grep -q '^setsid$'; then
        exec busybox setsid "$0" "$@"
    elif command -v python >/dev/null 2>&1; then
        exec python -c "import os, sys; os.setsid(); os.execv(sys.argv[1], sys.argv[1:])" "$0" "$@"
    fi
fi

LOG="/var/volatile/tmp/switch_to_freetoon.log"
mkdir -p /var/volatile/tmp 2>/dev/null || true

log() {
    _msg="[$(date '+%Y-%m-%d %H:%M:%S')] [freetoon] $*"
    echo "$_msg"
    echo "$_msg" >> "$LOG" 2>/dev/null || true
}

CHOICE_FILE="/mnt/data/ui_choice"
TOONUI_BIN="/mnt/data/toonui"
UI_LAUNCHER="/mnt/data/ui_launcher.sh"
INITTAB="/etc/inittab"
REPO_INSTALL_URL="https://raw.githubusercontent.com/ToonzDev/freetoon-lvgl/main/install.sh"
ACTION_FILE="/tmp/freetoon.action"
ACTION_FILE_ALT="/var/volatile/tmp/freetoon.action"

# Determine action: install (default) or uninstall
ACTION="install"
case "${1:-}" in
    --uninstall|-u|uninstall)
        ACTION="uninstall"
        ;;
    --install|-i|install)
        ACTION="install"
        ;;
    -h|--help)
        echo "Usage: $0 [install|uninstall]"
        echo "  install    Install FreeToon if missing, or switch to FreeToon (default)"
        echo "  uninstall  Uninstall FreeToon and restore stock qt-gui (keeps .cfg files)"
        exit 0
        ;;
    *)
        # Check action file triggered by QML app via TSC
        if [ -f "$ACTION_FILE" ] && grep -qi "uninstall" "$ACTION_FILE" 2>/dev/null; then
            ACTION="uninstall"
        elif [ -f "$ACTION_FILE_ALT" ] && grep -qi "uninstall" "$ACTION_FILE_ALT" 2>/dev/null; then
            ACTION="uninstall"
        fi
        ;;
esac
rm -f "$ACTION_FILE" "$ACTION_FILE_ALT" 2>/dev/null || true

# 1. Hardware detection
IS_TOON1=0
if [ -f /etc/opkg/arch.conf ] && ! grep -q nxt /etc/opkg/arch.conf 2>/dev/null; then
    IS_TOON1=1
    log "Hardware detected: Toon 1"
else
    log "Hardware detected: Toon 2"
fi

is_installed() {
    [ -f "$TOONUI_BIN" ] && [ -x "$TOONUI_BIN" ] && [ -f "$UI_LAUNCHER" ] && [ -x "$UI_LAUNCHER" ]
}

drop_inittab_row() {
    _id="$1"
    if grep -q "^${_id}:" "$INITTAB" 2>/dev/null; then
        log "Removing ${_id} row from $INITTAB..."
        grep -v "^${_id}:" "$INITTAB" > "$INITTAB.new" 2>/dev/null && mv -f "$INITTAB.new" "$INITTAB" 2>/dev/null || true
    fi
}

upsert_inittab_row() {
    _id="$1"
    _row="$2"
    grep -v "^${_id}:" "$INITTAB" > "$INITTAB.new" 2>/dev/null && \
        echo "$_row" >> "$INITTAB.new" && \
        mv -f "$INITTAB.new" "$INITTAB" 2>/dev/null || true
}

# ==============================================================================
# UNINSTALLATION ROUTINE
# ==============================================================================
if [ "$ACTION" = "uninstall" ]; then
    log "========================================================"
    log "Starting FreeToon uninstallation..."

    if ! is_installed && [ ! -f "$TOONUI_BIN" ] && [ ! -f "$UI_LAUNCHER" ]; then
        log "Notice: FreeToon binaries not detected, cleaning up configuration and entries..."
    fi

    # 1. Drop FreeToon-specific inittab rows
    log "Dropping FreeToon inittab entries..."
    drop_inittab_row toon
    drop_inittab_row vncs
    drop_inittab_row p1br
    drop_inittab_row qbri
    drop_inittab_row tuih

    # 2. Restore stock qt-gui in inittab
    log "Restoring stock qt-gui in $INITTAB..."
    sed -i 's~^#FREETOON#~~' "$INITTAB" 2>/dev/null || true
    if ! grep -qE '^[^#].*(startqt|qt-gui)' "$INITTAB" 2>/dev/null; then
        sed -i -E 's~^#+[ 	]*(qtqt:.*)~~' "$INITTAB" 2>/dev/null || true
    fi
    if ! grep -qE '^[^#].*(startqt|qt-gui)' "$INITTAB" 2>/dev/null; then
        echo 'qtqt:245:respawn:/usr/bin/startqt >/var/log/qt 2>&1' >> "$INITTAB"
    fi

    # 3. Restore OpenTherm hardware mode if proxy bridge was used
    if [ -x /mnt/data/ot_mode_switch.sh ]; then
        log "Restoring stock OpenTherm mode..."
        /mnt/data/ot_mode_switch.sh off >> "$LOG" 2>&1 || true
    fi
    pkill -9 -x quby_bridge 2>/dev/null || true
    pkill -9 -x p1bridge 2>/dev/null || true
    umount -l /dev/ttymxc0 2>/dev/null || true

    # 4. On Toon 1, restore 32bpp framebuffer depth
    if [ "$IS_TOON1" = 1 ] && command -v fbset >/dev/null 2>&1; then
        fbset -fb /dev/fb0 -depth 32 2>/dev/null || true
    fi

    # 5. Stop FreeToon processes
    log "Stopping FreeToon processes..."
    killall -9 toonui 2>/dev/null || true
    pkill -9 -x toonui 2>/dev/null || true
    pkill -9 -x x11vnc 2>/dev/null || true
    pkill -9 -x wastefetch 2>/dev/null || true
    pkill -9 -f /mnt/data/ui_launcher.sh 2>/dev/null || true
    pkill -9 -f /mnt/data/toon_wasm_host.sh 2>/dev/null || true

    # 6. Remove FreeToon binaries and scripts (PRESERVING *.cfg files!)
    log "Removing FreeToon binaries and scripts (keeping config files)..."
    rm -f /mnt/data/toonui \
          /mnt/data/ui_launcher.sh \
          /mnt/data/companion_gate.sh \
          /mnt/data/integrations-install.sh \
          /mnt/data/toonvnc.sh \
          /mnt/data/ot_mode_switch.sh \
          /mnt/data/fbvnc_input \
          /mnt/data/wastefetch \
          /mnt/data/p1bridge \
          /mnt/data/quby_bridge \
          /mnt/data/ui_choice \
          /mnt/data/toonvnc.plain \
          /mnt/data/qtlog \
          /mnt/data/toon_wasm_host.sh 2>/dev/null || true
    rm -rf /mnt/data/pwa /mnt/data/x11vnc-bundle 2>/dev/null || true

    # Clean runtime logs/state (keep switch log for review)
    rm -f /var/volatile/tmp/toonui* /var/volatile/tmp/ui_launcher.log 2>/dev/null || true
    rm -f /tmp/freetoon* /var/volatile/tmp/freetoon* 2>/dev/null || true

    # 7. Reload inittab so init respawns stock qt-gui
    log "Signaling init to reload inittab..."
    kill -HUP 1 2>/dev/null || telinit q 2>/dev/null || true
    sleep 1

    # Ensure stock Qt process is active
    if ! pidof qt-gui >/dev/null 2>&1 && ! pidof startqt >/dev/null 2>&1; then
        log "Kicking init to start stock qt-gui..."
        kill -HUP 1 2>/dev/null || telinit q 2>/dev/null || true
    fi

    log "FreeToon uninstalled successfully. Configuration files (e.g. toonui.cfg) have been preserved."
    exit 0
fi

# ==============================================================================
# INSTALL / SWITCH ROUTINE
# ==============================================================================
log "========================================================"
log "Starting FreeToon switch/install helper..."

# Reset crash counters so launcher gives FreeToon a clean start
rm -f /var/volatile/tmp/toonui_fails 2>/dev/null || true
touch /var/volatile/tmp/toonui_restart 2>/dev/null || true

if ! is_installed; then
    log "FreeToon is NOT installed. Starting installation..."

    # Pre-set choice to freetoon so installer doesn't default to qt-gui on Toon 1
    echo "freetoon" > "$CHOICE_FILE"

    # Locate installer: local file or download
    INSTALLER=""
    HERE="$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo "")"
    for cand in "$HERE/install.sh" "$HERE/../install.sh" /mnt/data/install.sh /root/install.sh; do
        if [ -s "$cand" ]; then
            INSTALLER="$cand"
            log "Using local installer found at: $INSTALLER"
            break
        fi
    done

    TMP_INSTALLER="/tmp/freetoon_install_$$.sh"
    rm -f "$TMP_INSTALLER" /tmp/freetoon_install_*.sh 2>/dev/null || true

    if [ -z "$INSTALLER" ]; then
        log "Fetching latest install.sh from GitHub ($REPO_INSTALL_URL)..."
        if command -v curl >/dev/null 2>&1; then
            curl -k -fsSL --connect-timeout 15 --max-time 60 -o "$TMP_INSTALLER" "$REPO_INSTALL_URL" >> "$LOG" 2>&1 || \
            curl -fsSL -4 --connect-timeout 15 --max-time 60 -o "$TMP_INSTALLER" "$REPO_INSTALL_URL" >> "$LOG" 2>&1 || true
        fi
        if [ ! -s "$TMP_INSTALLER" ] && command -v wget >/dev/null 2>&1; then
            wget --no-check-certificate -T 15 -O "$TMP_INSTALLER" "$REPO_INSTALL_URL" >> "$LOG" 2>&1 || \
            wget -T 15 -O "$TMP_INSTALLER" "$REPO_INSTALL_URL" >> "$LOG" 2>&1 || true
        fi

        if [ -s "$TMP_INSTALLER" ]; then
            INSTALLER="$TMP_INSTALLER"
            log "Successfully downloaded install.sh ($(wc -c < "$INSTALLER" 2>/dev/null || echo 0) bytes)"
        fi
    fi

    if [ -z "$INSTALLER" ] || [ ! -s "$INSTALLER" ]; then
        log "ERROR: Could not download or locate install.sh. Check network connection or check $LOG."
        rm -f "$TMP_INSTALLER" 2>/dev/null || true
        exit 1
    fi

    log "Executing installer: $INSTALLER"
    chmod +x "$INSTALLER"

    # Run installer; capture exit code without tripping set -e
    INSTALL_RC=0
    env FORCE_DOWNLOAD=1 sh "$INSTALLER" --download >> "$LOG" 2>&1 || INSTALL_RC=$?
    rm -f "$TMP_INSTALLER" 2>/dev/null || true

    # Step 6/6 of install.sh restarts the UI and terminates old Qt sessions,
    # which can return code 137 / Killed. Check if the files are actually on disk:
    if is_installed; then
        log "FreeToon binaries and launcher verified on disk. Installation completed successfully!"
    elif [ "$INSTALL_RC" -eq 0 ]; then
        log "Installation finished successfully."
    else
        log "ERROR: Installer exited with code $INSTALL_RC and FreeToon binaries are missing. See details in $LOG."
        exit 1
    fi

    # Ensure selection remains freetoon
    echo "freetoon" > "$CHOICE_FILE"

else
    log "FreeToon is already installed. Switching active UI to FreeToon..."

    # Set UI preference to freetoon
    echo "freetoon" > "$CHOICE_FILE"
fi

# Ensure inittab is properly wired and start FreeToon
TOON_ROW="toon:345:respawn:/mnt/data/ui_launcher.sh >> /var/volatile/tmp/toonui.log 2>&1"
if grep -qE '^([^#].*(startqt|qt-gui).*)' "$INITTAB" 2>/dev/null; then
    log "Disabling stock qt-gui in $INITTAB..."
    sed -i -E 's~^([^#].*(startqt|qt-gui).*)~#FREETOON#~' "$INITTAB" 2>/dev/null || true
fi

log "Ensuring FreeToon launcher is configured in $INITTAB..."
upsert_inittab_row toon "$TOON_ROW"

# Switch OT bridge mode if proxy is enabled in toonui.cfg
if [ -f /mnt/data/toonui.cfg ] && grep -q '^ot_bridge_mode=proxy' /mnt/data/toonui.cfg 2>/dev/null; then
    if [ -x /mnt/data/ot_mode_switch.sh ]; then
        log "Configuring OpenTherm proxy bridge..."
        /mnt/data/ot_mode_switch.sh proxy >> "$LOG" 2>&1 || true
    fi
fi

log "Signaling init to reload inittab..."
kill -HUP 1 2>/dev/null || telinit q 2>/dev/null || true
sleep 1

# Check if stock Qt processes are still lingering and terminate them
if pidof qt-gui >/dev/null 2>&1 || pidof startqt >/dev/null 2>&1; then
    log "Stopping lingering stock qt-gui processes..."
    killall -9 qt-gui 2>/dev/null || true
    pkill -9 -x qt-gui 2>/dev/null || true
    pkill -9 -f /qmf/sbin/qt-gui 2>/dev/null || true
    pkill -9 -x startqt 2>/dev/null || true
    kill -HUP 1 2>/dev/null || telinit q 2>/dev/null || true
fi

log "FreeToon launch initiated successfully."
exit 0
