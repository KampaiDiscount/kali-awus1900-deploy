#!/usr/bin/env bash
#
# AWUS1900 Deployment Utility for Kali Linux
# Target: ALFA AWUS1900 / Realtek RTL8814AU / USB ID 0bda:8813
#
# Default:
#   Installs Kali's dedicated realtek-rtl8814au-dkms package.
#   If the DKMS module cannot build for the running kernel, the script
#   cleans up and falls back to the in-kernel rtw88_8814au driver.
#
# Usage:
#   sudo bash awus1900-deploy.sh
#   sudo bash awus1900-deploy.sh auto
#   sudo bash awus1900-deploy.sh dkms
#   sudo bash awus1900-deploy.sh native
#   sudo bash awus1900-deploy.sh diagnose
#   sudo bash awus1900-deploy.sh smoke-test [channel]
#   sudo bash awus1900-deploy.sh remove
#

set -Eeuo pipefail
IFS=$'\n\t'
umask 022

VERSION="1.1.0"
TARGET_VENDOR="0bda"
TARGET_PRODUCT="8813"
TARGET_ID="${TARGET_VENDOR}:${TARGET_PRODUCT}"
DKMS_PACKAGE="realtek-rtl8814au-dkms"

BLACKLIST_FILE="/etc/modprobe.d/awus1900-dkms.conf"
UDEV_RULE_FILE="/etc/udev/rules.d/80-awus1900-power.rules"
STATUS_HELPER="/usr/local/sbin/awus1900-status"
MODE_HELPER="/usr/local/sbin/awus1900-mode"

LOG_DIR="/var/log/awus1900"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="${LOG_DIR}/deployment-${STAMP}.log"

ACTION="${1:-auto}"
CHANNEL="${2:-}"

C_RESET=$'\033[0m'
C_BLUE=$'\033[1;34m'
C_GREEN=$'\033[1;32m'
C_YELLOW=$'\033[1;33m'
C_RED=$'\033[1;31m'

info()  { printf '%s[+]%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok()    { printf '%s[OK]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn()  { printf '%s[!]%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
fatal() { printf '%s[ERROR]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

on_error() {
    local rc=$?
    warn "Command failed at line ${BASH_LINENO[0]} with exit code ${rc}."
    warn "Review: ${LOG_FILE}"
    exit "$rc"
}
trap on_error ERR

require_root() {
    [[ $EUID -eq 0 ]] || fatal "Run this script as root: sudo bash $0 ${ACTION}"
}

start_logging() {
    install -d -m 0755 "$LOG_DIR"
    touch "$LOG_FILE"
    chmod 0600 "$LOG_FILE"
    exec > >(tee -a "$LOG_FILE") 2>&1
}

require_commands() {
    local missing=()
    local command_name
    for command_name in "$@"; do
        command -v "$command_name" >/dev/null 2>&1 || missing+=("$command_name")
    done
    ((${#missing[@]} == 0)) || fatal "Missing required command(s): ${missing[*]}"
}

is_kali() {
    [[ -r /etc/os-release ]] && grep -qiE '(^ID=kali$|Kali GNU/Linux)' /etc/os-release
}

package_installed() {
    dpkg-query -W -f='${db:Status-Abbrev}' "$1" 2>/dev/null | grep -q '^ii'
}

target_present() {
    lsusb -d "$TARGET_ID" >/dev/null 2>&1
}

target_usb_node() {
    local node
    for node in /sys/bus/usb/devices/*; do
        [[ -r "${node}/idVendor" && -r "${node}/idProduct" ]] || continue
        if [[ "$(<"${node}/idVendor")" == "$TARGET_VENDOR" &&
              "$(<"${node}/idProduct")" == "$TARGET_PRODUCT" ]]; then
            basename "$node"
            return 0
        fi
    done
    return 1
}

target_interface() {
    local netdev iface props driver_module
    for netdev in /sys/class/net/*; do
        [[ -e "$netdev" ]] || continue
        iface="$(basename "$netdev")"
        [[ "$iface" == "lo" ]] && continue

        props="$(udevadm info -q property -p "$netdev" 2>/dev/null || true)"
        if grep -qx "ID_VENDOR_ID=${TARGET_VENDOR}" <<<"$props" &&
           grep -qx "ID_MODEL_ID=${TARGET_PRODUCT}" <<<"$props"; then
            printf '%s\n' "$iface"
            return 0
        fi

        driver_module=""
        if [[ -L "${netdev}/device/driver/module" ]]; then
            driver_module="$(basename "$(readlink -f "${netdev}/device/driver/module")")"
        fi
        if [[ "$driver_module" == "8814au" || "$driver_module" == "rtw88_8814au" ]]; then
            printf '%s\n' "$iface"
            return 0
        fi
    done
    return 1
}

driver_for_interface() {
    local iface="$1"
    if command -v ethtool >/dev/null 2>&1; then
        ethtool -i "$iface" 2>/dev/null | awk -F': ' '/^driver:/ {print $2; exit}'
    fi
}

usb_speed_report() {
    local node speed
    if node="$(target_usb_node 2>/dev/null)" && [[ -r "/sys/bus/usb/devices/${node}/speed" ]]; then
        speed="$(<"/sys/bus/usb/devices/${node}/speed")"
        info "USB device node: ${node}; negotiated speed: ${speed} Mbit/s"
        case "$speed" in
            5000|10000|20000)
                ok "The adapter is attached through a SuperSpeed USB path."
                ;;
            *)
                warn "The adapter is not reporting a 5 Gbit/s-or-faster USB path."
                warn "Confirm VirtualBox USB 3.0 (xHCI) and toggle the Realtek USB device."
                ;;
        esac
    fi
}

show_banner() {
    cat <<EOF

============================================================
  ALFA AWUS1900 Deployment Utility v${VERSION}
  RTL8814AU | USB ${TARGET_ID} | Kali Linux
============================================================

EOF
}

show_platform() {
    info "Host information:"
    printf '  Kernel: %s\n' "$(uname -r)"
    printf '  Architecture: %s\n' "$(uname -m)"
    if [[ -r /etc/os-release ]]; then
        printf '  OS: %s\n' "$(. /etc/os-release; printf '%s' "${PRETTY_NAME:-unknown}")"
    fi

    if ! is_kali; then
        warn "This does not appear to be Kali Linux. Continuing is unsupported."
    fi

    if target_present; then
        ok "Detected ALFA AWUS1900-compatible USB ID ${TARGET_ID}."
        lsusb -d "$TARGET_ID" || true
        usb_speed_report
    else
        warn "USB ID ${TARGET_ID} is not currently visible inside Kali."
        warn "The driver can still be installed, but runtime validation will be deferred."
        warn "In VirtualBox, select Devices -> USB -> Realtek 802.11ac NIC."
    fi
}

apt_update() {
    info "Refreshing APT metadata..."
    DEBIAN_FRONTEND=noninteractive apt-get update
}

install_common_packages() {
    info "Installing wireless, firmware and diagnostic prerequisites..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        aircrack-ng \
        bc \
        build-essential \
        dkms \
        ethtool \
        firmware-realtek \
        iw \
        libelf-dev \
        mokutil \
        rfkill \
        usbutils
}

ensure_running_kernel_headers() {
    local kernel header_package
    kernel="$(uname -r)"
    header_package="linux-headers-${kernel}"

    if [[ -e "/lib/modules/${kernel}/build/Makefile" ]]; then
        ok "Headers already match the running kernel ${kernel}."
        return 0
    fi

    info "Looking for exact headers: ${header_package}"
    if apt-cache show "$header_package" >/dev/null 2>&1; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y "$header_package"
    else
        warn "Exact headers for the running kernel are not available from the enabled repository."
        warn "The script will use the native rtw88_8814au driver instead of forcing a kernel upgrade."
        return 1
    fi

    [[ -e "/lib/modules/${kernel}/build/Makefile" ]]
}

write_power_rule() {
    info "Installing an AWUS1900 USB autosuspend override..."
    cat > "$UDEV_RULE_FILE" <<'EOF'
# ALFA AWUS1900 / RTL8814AU: keep the high-draw USB adapter fully powered.
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0bda", ATTR{idProduct}=="8813", TEST=="power/control", ATTR{power/control}="on"
EOF
    chmod 0644 "$UDEV_RULE_FILE"
    udevadm control --reload-rules
    udevadm trigger --subsystem-match=usb --attr-match=idVendor="$TARGET_VENDOR" --attr-match=idProduct="$TARGET_PRODUCT" || true
}

write_dkms_blacklist() {
    info "Preventing the native RTL8814AU driver from racing the DKMS driver..."
    cat > "$BLACKLIST_FILE" <<'EOF'
# AWUS1900 deployment: use Kali's standalone 8814au DKMS module.
# Blacklist only the RTL8814AU-specific rtw88 modules; do not blacklist
# the common rtw88 core because other Realtek adapters may need it.
blacklist rtw88_8814au
blacklist rtw88_8814a
EOF
    chmod 0644 "$BLACKLIST_FILE"
}

remove_dkms_blacklist() {
    if [[ -e "$BLACKLIST_FILE" ]]; then
        info "Removing the AWUS1900 DKMS driver blacklist..."
        rm -f "$BLACKLIST_FILE"
    fi
}

write_helpers() {
    info "Installing awus1900-status and awus1900-mode helpers..."

    cat > "$STATUS_HELPER" <<'STATUS_EOF'
#!/usr/bin/env bash
set -u

TARGET_VENDOR="0bda"
TARGET_PRODUCT="8813"
TARGET_ID="${TARGET_VENDOR}:${TARGET_PRODUCT}"

find_iface() {
    local netdev iface props module
    for netdev in /sys/class/net/*; do
        [[ -e "$netdev" ]] || continue
        iface="$(basename "$netdev")"
        [[ "$iface" == "lo" ]] && continue
        props="$(udevadm info -q property -p "$netdev" 2>/dev/null || true)"
        if grep -qx "ID_VENDOR_ID=${TARGET_VENDOR}" <<<"$props" &&
           grep -qx "ID_MODEL_ID=${TARGET_PRODUCT}" <<<"$props"; then
            echo "$iface"
            return 0
        fi
        module=""
        [[ -L "${netdev}/device/driver/module" ]] &&
            module="$(basename "$(readlink -f "${netdev}/device/driver/module")")"
        if [[ "$module" == "8814au" || "$module" == "rtw88_8814au" ]]; then
            echo "$iface"
            return 0
        fi
    done
    return 1
}

echo "=== AWUS1900 status ==="
echo "Kernel: $(uname -r)"
echo
echo "--- USB ---"
lsusb -d "$TARGET_ID" 2>/dev/null || echo "USB ${TARGET_ID} not visible"
lsusb -t 2>/dev/null || true
echo
echo "--- Modules ---"
lsmod | grep -E '(^8814au|rtw88_8814|rtw88_usb|rtw88_core)' || echo "No RTL8814AU module loaded"
echo
echo "--- DKMS ---"
dkms status 2>/dev/null | grep -Ei '8814|realtek' || echo "No RTL8814AU DKMS entry"
echo
echo "--- Interface ---"
if iface="$(find_iface)"; then
    echo "Interface: $iface"
    ethtool -i "$iface" 2>/dev/null || true
    ip -br link show "$iface" 2>/dev/null || true
    iw dev "$iface" info 2>/dev/null || true
else
    echo "No AWUS1900 interface detected"
fi
echo
echo "--- rfkill ---"
rfkill list 2>/dev/null || true
STATUS_EOF

    cat > "$MODE_HELPER" <<'MODE_EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

TARGET_VENDOR="0bda"
TARGET_PRODUCT="8813"

usage() {
    cat <<'EOF'
Usage:
  sudo awus1900-mode monitor [channel]
  sudo awus1900-mode managed
  awus1900-mode status

Examples:
  sudo awus1900-mode monitor
  sudo awus1900-mode monitor 36
  sudo awus1900-mode managed
EOF
}

find_iface() {
    local netdev iface props module
    for netdev in /sys/class/net/*; do
        [[ -e "$netdev" ]] || continue
        iface="$(basename "$netdev")"
        [[ "$iface" == "lo" ]] && continue
        props="$(udevadm info -q property -p "$netdev" 2>/dev/null || true)"
        if grep -qx "ID_VENDOR_ID=${TARGET_VENDOR}" <<<"$props" &&
           grep -qx "ID_MODEL_ID=${TARGET_PRODUCT}" <<<"$props"; then
            echo "$iface"
            return 0
        fi
        module=""
        [[ -L "${netdev}/device/driver/module" ]] &&
            module="$(basename "$(readlink -f "${netdev}/device/driver/module")")"
        if [[ "$module" == "8814au" || "$module" == "rtw88_8814au" ]]; then
            echo "$iface"
            return 0
        fi
    done
    return 1
}

action="${1:-status}"
channel="${2:-}"

if [[ "$action" == "status" ]]; then
    exec /usr/local/sbin/awus1900-status
fi

[[ $EUID -eq 0 ]] || { echo "Run this action as root." >&2; exit 1; }
iface="$(find_iface)" || { echo "AWUS1900 interface not found." >&2; exit 1; }

case "$action" in
    monitor)
        rfkill unblock wlan || true
        command -v nmcli >/dev/null 2>&1 && nmcli device set "$iface" managed no || true
        ip link set "$iface" down
        iw dev "$iface" set type monitor
        ip link set "$iface" up
        if [[ -n "$channel" ]]; then
            iw dev "$iface" set channel "$channel"
        fi
        iw dev "$iface" info
        ;;
    managed)
        ip link set "$iface" down
        iw dev "$iface" set type managed
        ip link set "$iface" up
        if command -v nmcli >/dev/null 2>&1; then
            nmcli device set "$iface" managed yes || true
            systemctl try-restart NetworkManager.service || true
        fi
        iw dev "$iface" info
        ;;
    *)
        usage
        exit 2
        ;;
esac
MODE_EOF

    chmod 0755 "$STATUS_HELPER" "$MODE_HELPER"
}

capture_dkms_logs() {
    local destination="${LOG_DIR}/dkms-failure-${STAMP}.txt"
    {
        echo "AWUS1900 DKMS failure capture"
        echo "Generated: $(date -Is)"
        echo "Kernel: $(uname -r)"
        echo
        dkms status 2>&1 || true
        echo
        find /var/lib/dkms -path '*realtek-rtl8814au*' -name make.log -type f -print 2>/dev/null |
        while read -r make_log; do
            echo "===== ${make_log} ====="
            cat "$make_log"
            echo
        done
    } > "$destination"
    warn "DKMS build logs captured in ${destination}"
}

purge_conflicting_vendor_driver() {
    local package
    for package in realtek-rtl88xxau-dkms rtl8812au-dkms rtl8814au-dkms; do
        if package_installed "$package"; then
            warn "Removing potentially conflicting package: ${package}"
            DEBIAN_FRONTEND=noninteractive apt-get purge -y "$package"
        fi
    done
}

load_dkms_driver() {
    local iface=""
    iface="$(target_interface 2>/dev/null || true)"
    if [[ -n "$iface" ]]; then
        command -v nmcli >/dev/null 2>&1 && nmcli device set "$iface" managed no || true
        ip link set "$iface" down || true
    fi

    modprobe -r rtw88_8814au 2>/dev/null || true
    modprobe -r rtw88_8814a 2>/dev/null || true
    modprobe -r 8814au 2>/dev/null || true
    modprobe 8814au
    udevadm settle
}

load_native_driver() {
    local iface=""
    iface="$(target_interface 2>/dev/null || true)"
    if [[ -n "$iface" ]]; then
        command -v nmcli >/dev/null 2>&1 && nmcli device set "$iface" managed no || true
        ip link set "$iface" down || true
    fi

    modprobe -r 8814au 2>/dev/null || true
    modprobe -r rtw88_8814au 2>/dev/null || true
    modprobe rtw88_8814au
    udevadm settle
}

validate_runtime() {
    local expected="$1"
    local iface driver

    echo
    info "Runtime validation..."

    if ! target_present; then
        warn "Adapter is not attached, so the installed driver cannot be runtime-tested."
        warn "Attach it through VirtualBox and run: sudo bash \"$0\" diagnose"
        return 0
    fi

    iface="$(target_interface 2>/dev/null || true)"
    if [[ -z "$iface" ]]; then
        warn "The USB adapter is present but no wireless interface appeared."
        warn "Toggle Devices -> USB -> Realtek 802.11ac NIC, or reboot the VM."
        return 0
    fi

    driver="$(driver_for_interface "$iface" || true)"
    info "Interface: ${iface}"
    info "Bound driver: ${driver:-unknown}"

    if [[ "$expected" == "dkms" && "$driver" != "8814au" ]]; then
        warn "Expected DKMS driver 8814au, but ${driver:-no driver} is bound."
        warn "A reboot or VirtualBox USB detach/reattach may be required."
    elif [[ "$expected" == "native" && "$driver" != "rtw88_8814au" ]]; then
        warn "Expected native driver rtw88_8814au, but ${driver:-no driver} is bound."
        warn "A reboot or VirtualBox USB detach/reattach may be required."
    else
        ok "The expected driver is bound to ${iface}."
    fi

    rfkill unblock wlan || true
    ip -br link show "$iface" || true
    iw dev "$iface" info || true

    if iw list 2>/dev/null | sed -n '/Supported interface modes:/,/Band /p' | grep -q '\* monitor'; then
        ok "The active wireless stack advertises monitor mode."
    else
        warn "Monitor mode was not found in the current iw capability report."
    fi
}

install_native() {
    info "Configuring the in-kernel rtw88_8814au driver..."

    if package_installed "$DKMS_PACKAGE"; then
        DEBIAN_FRONTEND=noninteractive apt-get purge -y "$DKMS_PACKAGE" || true
    fi

    remove_dkms_blacklist
    depmod -a

    if ! modinfo rtw88_8814au >/dev/null 2>&1; then
        fatal "The running kernel does not contain rtw88_8814au."
    fi

    if [[ ! -e /usr/lib/firmware/rtw88/rtw8814a_fw.bin &&
          ! -e /usr/lib/firmware/rtw88/rtw8814a_fw.bin.zst &&
          ! -e /lib/firmware/rtw88/rtw8814a_fw.bin &&
          ! -e /lib/firmware/rtw88/rtw8814a_fw.bin.zst ]]; then
        fatal "RTL8814AU firmware is missing even after installing firmware-realtek."
    fi

    write_power_rule
    write_helpers

    if target_present; then
        if load_native_driver; then
            ok "Loaded native rtw88_8814au."
        else
            warn "Could not hot-load the native driver. Reboot the VM."
        fi
    fi

    validate_runtime native
    ok "Native-driver deployment completed."
}

install_dkms() {
    local kernel rc
    kernel="$(uname -r)"

    info "Preparing Kali's standalone RTL8814AU DKMS driver..."

    if ! ensure_running_kernel_headers; then
        install_native
        return 0
    fi

    purge_conflicting_vendor_driver

    info "Installing ${DKMS_PACKAGE}..."
    set +e
    DEBIAN_FRONTEND=noninteractive apt-get install -y --reinstall "$DKMS_PACKAGE"
    rc=$?
    set -e

    if ((rc != 0)); then
        warn "${DKMS_PACKAGE} failed to install."
        capture_dkms_logs
        DEBIAN_FRONTEND=noninteractive apt-get purge -y "$DKMS_PACKAGE" || true
        dpkg --configure -a || true
        DEBIAN_FRONTEND=noninteractive apt-get -f install -y || true
        remove_dkms_blacklist
        warn "Falling back cleanly to the native driver."
        install_native
        return 0
    fi

    info "Running DKMS autoinstall for ${kernel}..."
    set +e
    dkms autoinstall -k "$kernel"
    rc=$?
    set -e

    if ((rc != 0)) || ! modinfo -k "$kernel" 8814au >/dev/null 2>&1; then
        warn "The 8814au DKMS module did not build successfully for ${kernel}."
        capture_dkms_logs
        DEBIAN_FRONTEND=noninteractive apt-get purge -y "$DKMS_PACKAGE" || true
        dpkg --configure -a || true
        DEBIAN_FRONTEND=noninteractive apt-get -f install -y || true
        remove_dkms_blacklist
        warn "Falling back cleanly to the native driver."
        install_native
        return 0
    fi

    depmod -a "$kernel"
    write_dkms_blacklist
    write_power_rule
    write_helpers

    if target_present; then
        if load_dkms_driver; then
            ok "Loaded standalone 8814au DKMS driver."
        else
            warn "Could not hot-switch to 8814au. Reboot or toggle the USB device."
        fi
    fi

    validate_runtime dkms
    ok "DKMS-driver deployment completed."
}

diagnose() {
    local iface="" driver="" node=""

    echo
    info "Collecting AWUS1900 diagnostics..."
    printf 'Date: %s\n' "$(date -Is)"
    printf 'Kernel: %s\n' "$(uname -a)"
    printf 'Action log: %s\n' "$LOG_FILE"

    echo
    echo "=== OS ==="
    cat /etc/os-release 2>/dev/null || true

    echo
    echo "=== Repository branch ==="
    grep -RhsE '^(Suites:|deb .*kali)' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null || true

    echo
    echo "=== USB ==="
    lsusb || true
    lsusb -t || true
    if node="$(target_usb_node 2>/dev/null)"; then
        echo "Target USB node: $node"
        [[ -r "/sys/bus/usb/devices/${node}/speed" ]] &&
            echo "Target speed: $(<"/sys/bus/usb/devices/${node}/speed") Mbit/s"
        for intf in /sys/bus/usb/devices/"${node}":*; do
            [[ -e "$intf" ]] || continue
            printf '%s driver: ' "$(basename "$intf")"
            basename "$(readlink -f "${intf}/driver" 2>/dev/null)" 2>/dev/null || echo "none"
        done
    fi

    echo
    echo "=== Packages ==="
    apt-cache policy "$DKMS_PACKAGE" firmware-realtek 2>/dev/null || true
    dpkg-query -W -f='${binary:Package}\t${Version}\t${db:Status-Abbrev}\n' \
        "$DKMS_PACKAGE" firmware-realtek dkms 2>/dev/null || true

    echo
    echo "=== Kernel modules ==="
    lsmod | grep -E '(^8814au|rtw88_8814|rtw88_usb|rtw88_core)' || true
    modinfo 8814au 2>/dev/null | sed -n '1,20p' || true
    modinfo rtw88_8814au 2>/dev/null | sed -n '1,20p' || true

    echo
    echo "=== DKMS ==="
    dkms status 2>/dev/null || true

    echo
    echo "=== Wireless ==="
    iw dev 2>/dev/null || true
    rfkill list 2>/dev/null || true

    iface="$(target_interface 2>/dev/null || true)"
    if [[ -n "$iface" ]]; then
        driver="$(driver_for_interface "$iface" || true)"
        echo "Target interface: $iface"
        echo "Target driver: ${driver:-unknown}"
        ethtool -i "$iface" 2>/dev/null || true
        ip -details link show "$iface" 2>/dev/null || true
        iw dev "$iface" info 2>/dev/null || true
    fi

    echo
    echo "=== Configuration ==="
    for file in "$BLACKLIST_FILE" "$UDEV_RULE_FILE"; do
        if [[ -r "$file" ]]; then
            echo "--- $file ---"
            cat "$file"
        fi
    done

    echo
    echo "=== Recent kernel messages ==="
    dmesg --color=never 2>/dev/null |
        grep -Ei '8814|rtw88|firmware|usb.*(reset|disconnect|error|fail)' |
        tail -n 160 || true

    ok "Diagnostic report completed: ${LOG_FILE}"
}

smoke_test() {
    local iface original_type managed_by_nm=0 channel="${CHANNEL:-}"
    iface="$(target_interface 2>/dev/null || true)"
    [[ -n "$iface" ]] || fatal "No AWUS1900 interface is available."

    original_type="$(iw dev "$iface" info | awk '/type/ {print $2; exit}')"
    [[ -n "$original_type" ]] || original_type="managed"

    if command -v nmcli >/dev/null 2>&1; then
        if nmcli -t -f GENERAL.STATE device show "$iface" >/dev/null 2>&1; then
            managed_by_nm=1
        fi
        nmcli device set "$iface" managed no || true
    fi

    restore_smoke_test() {
        ip link set "$iface" down 2>/dev/null || true
        iw dev "$iface" set type "$original_type" 2>/dev/null || true
        ip link set "$iface" up 2>/dev/null || true
        if ((managed_by_nm)); then
            nmcli device set "$iface" managed yes 2>/dev/null || true
            systemctl try-restart NetworkManager.service 2>/dev/null || true
        fi
    }
    trap restore_smoke_test EXIT

    info "Temporarily switching ${iface} from ${original_type} to monitor mode..."
    rfkill unblock wlan || true
    ip link set "$iface" down
    iw dev "$iface" set type monitor
    ip link set "$iface" up

    if [[ -n "$channel" ]]; then
        iw dev "$iface" set channel "$channel"
    fi

    iw dev "$iface" info
    [[ "$(iw dev "$iface" info | awk '/type/ {print $2; exit}')" == "monitor" ]] ||
        fatal "The interface did not enter monitor mode."

    ok "Monitor-mode smoke test passed."
    info "This test does not transmit frames or prove packet injection."
}

remove_deployment() {
    info "Removing the standalone AWUS1900 deployment..."

    modprobe -r 8814au 2>/dev/null || true

    if package_installed "$DKMS_PACKAGE"; then
        DEBIAN_FRONTEND=noninteractive apt-get purge -y "$DKMS_PACKAGE"
    fi

    rm -f "$BLACKLIST_FILE" "$UDEV_RULE_FILE" "$STATUS_HELPER" "$MODE_HELPER"
    udevadm control --reload-rules || true
    depmod -a

    if modinfo rtw88_8814au >/dev/null 2>&1; then
        modprobe rtw88_8814au 2>/dev/null || true
        ok "Standalone deployment removed; native rtw88_8814au is available."
    else
        warn "Standalone deployment removed, but this kernel has no native rtw88_8814au."
    fi
}

usage() {
    cat <<EOF
Usage:
  sudo bash $0                 Automatic DKMS attempt, with native fallback
  sudo bash $0 auto            Same as default
  sudo bash $0 dkms            Explicitly attempt the DKMS path
  sudo bash $0 native          Use the in-kernel rtw88_8814au driver
  sudo bash $0 diagnose        Generate a hardware/driver report
  sudo bash $0 smoke-test [ch] Non-transmitting monitor-mode test
  sudo bash $0 remove          Remove deployment and return to native driver

Installed helpers:
  awus1900-status
  sudo awus1900-mode monitor [channel]
  sudo awus1900-mode managed
EOF
}

main() {
    case "$ACTION" in
        help|-h|--help)
            show_banner
            usage
            return 0
            ;;
        version|-V|--version)
            printf '%s\n' "$VERSION"
            return 0
            ;;
    esac

    require_root
    start_logging
    show_banner
    require_commands apt-get dpkg-query lsusb modprobe udevadm
    show_platform

    case "$ACTION" in
        auto|dkms|install)
            apt_update
            install_common_packages
            install_dkms
            ;;
        native)
            apt_update
            install_common_packages
            install_native
            ;;
        diagnose)
            diagnose
            ;;
        smoke-test)
            smoke_test
            ;;
        remove|uninstall)
            remove_deployment
            ;;
        *)
            usage
            fatal "Unknown action: ${ACTION}"
            ;;
    esac

    echo
    ok "Finished. Full log: ${LOG_FILE}"
}

main "$@"
