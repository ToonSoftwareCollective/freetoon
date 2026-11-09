#!/bin/sh
# freetoon.sh - Install FreeToon if not present, switch to FreeToon from stock qt-gui,
# or uninstall FreeToon and revert cleanly to stock qt-gui.
# Compatible with FreeToon 1.0.5+ (Toon 1 and Toon 2).
# Kicked off by TSC ("external-freetoon") from the Freetoon QML app, or from a shell.
#
# INITTAB SAFETY: this script never edits /etc/inittab itself. Every change goes
# through inittab_edit.sh (lock, free-space check, validation of the new file,
# sync + atomic rename). If no working inittab_edit.sh is available, the script
# stops WITHOUT touching inittab. The installer is always the latest install.sh
# from GitHub main; no bundled copy is used.

set -e

# Prevent being killed if parent process (e.g. qt-gui / TSC child) exits
trap '' HUP TERM INT

# `command -v` does not exist in the Toon 1 shell; `type` does.
have() { type "$1" >/dev/null 2>&1; }

# Decouple from parent process group / session so init killing startqt does not kill this script
if [ "${SWITCH_DETACHED:-0}" != "1" ]; then
    export SWITCH_DETACHED=1
    if have setsid; then
        exec setsid "$0" "$@"
    elif have busybox && busybox --list 2>/dev/null | grep -q '^setsid$'; then
        exec busybox setsid "$0" "$@"
    elif have python; then
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
RAW_BASE="https://raw.githubusercontent.com/ToonzDev/freetoon-lvgl/main"
REPO_INSTALL_URL="$RAW_BASE/install.sh"
ENGINE_URL="$RAW_BASE/scripts/inittab_edit.sh"
ENGINE_INSTALLED="/mnt/data/inittab_edit.sh"
ENGINE_TMP="/var/volatile/tmp/inittab_edit.sh"
ENGINE=""
ACTION_FILE="/tmp/freetoon.action"
ACTION_FILE_ALT="/var/volatile/tmp/freetoon.action"
TOON_ROW="toon:2345:respawn:/mnt/data/ui_launcher.sh >> /var/volatile/tmp/toonui.log 2>&1"

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

# Download $1 to $2. Returns 0 only if a non-empty file arrived.
fetch() {
    _url="$1"; _out="$2"
    rm -f "$_out" 2>/dev/null || true
    if have curl; then
        curl -k -fsSL --connect-timeout 15 --max-time 60 -o "$_out" "$_url" >> "$LOG" 2>&1 || \
        curl -fsSL -4 --connect-timeout 15 --max-time 60 -o "$_out" "$_url" >> "$LOG" 2>&1 || true
    fi
    if [ ! -s "$_out" ] && have wget; then
        wget --no-check-certificate -T 15 -O "$_out" "$_url" >> "$LOG" 2>&1 || \
        wget -T 15 -O "$_out" "$_url" >> "$LOG" 2>&1 || true
    fi
    [ -s "$_out" ]
}

# A usable engine is a syntactically valid inittab_edit.sh that knows commit_inittab.
engine_ok() {
    [ -s "$1" ] && grep -q 'commit_inittab' "$1" 2>/dev/null && sh -n "$1" 2>/dev/null
}

# Select the inittab engine: the latest from GitHub, else the one installed in /mnt/data.
# Also verifies the CURRENT inittab passes validation; if not, nothing is edited.
select_engine() {
    if fetch "$ENGINE_URL" "$ENGINE_TMP" && engine_ok "$ENGINE_TMP"; then
        ENGINE="$ENGINE_TMP"
    elif engine_ok "$ENGINE_INSTALLED"; then
        ENGINE="$ENGINE_INSTALLED"
    else
        log "ERROR: no usable inittab_edit.sh (download failed, none installed). /etc/inittab NOT modified."
        return 1
    fi
    log "Using inittab engine: $ENGINE"
    if ! sh "$ENGINE" check >> "$LOG" 2>&1; then
        log "ERROR: current /etc/inittab does not pass validation. Refusing to modify it."
        return 1
    fi
}

# Run one engine command; log and return its status (never edits inittab directly).
it_edit() {
    if sh "$ENGINE" "$@" >> "$LOG" 2>&1; then
        return 0
    fi
    log "ERROR: inittab_edit.sh $1 failed - /etc/inittab left unchanged for this step."
    return 1
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

    select_engine || { log "Uninstall aborted; FreeToon left in place."; exit 1; }

    # 1. Restore stock qt-gui FIRST, so the Toon always has a UI row even if a
    #    later step fails (a brief overlap with FreeToon is harmless; no UI is not).
    log "Restoring stock qt-gui in /etc/inittab..."
    echo "qt-gui" > "$CHOICE_FILE" 2>/dev/null || true
    it_edit restore_stock_qt || { log "Uninstall aborted; FreeToon left in place."; exit 1; }

    # 2. Restore OpenTherm hardware mode if proxy bridge was used (drops qbri itself)
    if [ -x /mnt/data/ot_mode_switch.sh ]; then
        log "Restoring stock OpenTherm mode..."
        /mnt/data/ot_mode_switch.sh off >> "$LOG" 2>&1 || true
    fi

    # 3. Drop FreeToon-specific inittab rows (only those present)
    log "Dropping FreeToon inittab entries..."
    for _id in toon vncs p1br qbri tuih; do
        if grep -q "^${_id}:" /etc/inittab 2>/dev/null; then
            log "Removing ${_id} row from /etc/inittab..."
            it_edit drop "$_id" || true
        fi
    done

    pkill -9 -x quby_bridge 2>/dev/null || true
    pkill -9 -x p1bridge 2>/dev/null || true
    umount -l /dev/ttymxc0 2>/dev/null || true

    # 4. Toon 1 framebuffer: i.MX27 LCDC is 16bpp for both FreeToon and stock qt-gui
    if [ "$IS_TOON1" = 1 ] && have fbset; then
        fbset -fb /dev/fb0 -depth 16 2>/dev/null || true
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
    #    Only remove binaries whose inittab rows are really gone.
    if grep -qE '^(toon|vncs|p1br|qbri|tuih):' /etc/inittab 2>/dev/null; then
        log "WARNING: some FreeToon inittab rows could not be removed; keeping binaries so they do not respawn-loop."
    else
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
              /mnt/data/toon_wasm_host.sh \
              "$ENGINE_INSTALLED" 2>/dev/null || true
        rm -rf /mnt/data/pwa /mnt/data/x11vnc-bundle 2>/dev/null || true
    fi

    # Clean runtime logs/state (keep switch log for review)
    rm -f /var/volatile/tmp/toonui* /var/volatile/tmp/ui_launcher.log 2>/dev/null || true
    rm -f /tmp/freetoon* /var/volatile/tmp/freetoon* "$ENGINE_TMP" 2>/dev/null || true

    # 7. Make sure init has the final inittab and stock Qt runs
    kill -HUP 1 2>/dev/null || telinit q 2>/dev/null || true
    sleep 1
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

    # Always use the LATEST installer from GitHub (never a bundled copy):
    # it carries the current inittab safety fixes and deploys inittab_edit.sh.
    INSTALLER="/var/volatile/tmp/freetoon_install_$$.sh"
    rm -f /var/volatile/tmp/freetoon_install_*.sh /tmp/freetoon_install_*.sh 2>/dev/null || true
    log "Fetching latest install.sh from GitHub ($REPO_INSTALL_URL)..."
    if ! fetch "$REPO_INSTALL_URL" "$INSTALLER" || ! head -n 1 "$INSTALLER" | grep -q '^#!' || ! sh -n "$INSTALLER" 2>/dev/null; then
        log "ERROR: Could not download a valid install.sh. Check network connection or check $LOG."
        rm -f "$INSTALLER" 2>/dev/null || true
        exit 1
    fi
    log "Successfully downloaded install.sh ($(wc -c < "$INSTALLER" 2>/dev/null || echo 0) bytes)"

    log "Executing installer: $INSTALLER"
    # Run installer; capture exit code without tripping set -e
    INSTALL_RC=0
    env FORCE_DOWNLOAD=1 sh "$INSTALLER" --download >> "$LOG" 2>&1 || INSTALL_RC=$?
    rm -f "$INSTALLER" 2>/dev/null || true

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
    echo "freetoon" > "$CHOICE_FILE"
fi

# Wire inittab via the engine. Add the FreeToon row FIRST and only then disable
# stock Qt, so a failure can never leave the Toon without any UI row.
select_engine || { log "Switch aborted; stock qt-gui left active."; exit 1; }

log "Ensuring FreeToon launcher is configured in /etc/inittab..."
if ! grep -qF "$TOON_ROW" /etc/inittab 2>/dev/null; then
    it_edit upsert toon "$TOON_ROW" || { log "Switch aborted; stock qt-gui left active."; exit 1; }
fi

if grep -E '^[^#].*(startqt|qt-gui)' /etc/inittab >/dev/null 2>&1; then
    log "Disabling stock qt-gui in /etc/inittab..."
    it_edit comment_pattern 'startqt|qt-gui' || log "WARNING: could not disable stock qt-gui row; FreeToon row is active."
fi

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

rm -f "$ENGINE_TMP" 2>/dev/null || true
log "FreeToon launch initiated successfully."
exit 0
