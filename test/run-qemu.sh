#!/usr/bin/env bash
# Boot a UEFI application under QEMU/OVMF and check its console output.
#
# usage: test/run-qemu.sh APP.efi [EXPECTED TEXT] [--keep] [--file HOST:ESP]
#
#   --file HOST:ESP   copy a host file onto the ESP image (repeatable).
#                     The target directory must already exist, e.g.
#                     --file logo.bmp:/EFI/BOOT/LOGO.BMP
#
# Environment:
#   OVMF_CODE, OVMF_VARS  explicit firmware paths
#   OVMF_DIR              directory containing OVMF_CODE.fd / OVMF_VARS.fd
#   QEMU_TIMEOUT          seconds to wait (default 45)

set -euo pipefail

[[ $# -ge 1 ]] || { echo "usage: run-qemu.sh APP.efi [EXPECTED TEXT] [--keep] [--file HOST:ESP]" >&2; exit 2; }

APP=$1
shift
EXPECT=
KEEP=0
FILES=()
while [[ $# -gt 0 ]]; do
    case $1 in
        --keep)
            KEEP=1
            ;;
        --file)
            [[ $# -ge 2 ]] || { echo "run-qemu: --file needs HOST:ESP" >&2; exit 2; }
            FILES+=("$2")
            shift
            ;;
        -*)
            echo "run-qemu: unknown option '$1'" >&2
            exit 2
            ;;
        *)
            if [[ -n $EXPECT ]]; then
                echo "run-qemu: unexpected argument '$1'" >&2
                exit 2
            fi
            EXPECT=$1
            ;;
    esac
    shift
done
EXPECT=${EXPECT:-Hello from Ada!}

QEMU=${QEMU:-qemu-system-x86_64}
OUT=${OUT:-test/out}

if ! command -v "$QEMU" >/dev/null 2>&1; then
    echo "run-qemu: $QEMU not found" >&2
    exit 1
fi
for tool in dd mkfs.fat mmd mcopy; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "run-qemu: required tool '$tool' not found" >&2
        exit 1
    fi
done

find_firmware() {
    if [[ -n ${OVMF_CODE:-} && -n ${OVMF_VARS:-} ]]; then
        return
    fi
    local dirs=()
    [[ -n ${OVMF_DIR:-} ]] && dirs+=("$OVMF_DIR")
    dirs+=(/usr/share/OVMF /usr/share/edk2/ovmf /usr/share/edk2/x64
           /usr/share/edk2-ovmf /usr/local/share/OVMF)
    # shellcheck disable=SC2206
    dirs+=(/nix/store/*OVMF*/FV /nix/store/*ovmf*/FV)
    local d
    for d in "${dirs[@]}"; do
        if [[ -f $d/OVMF_CODE.fd && -f $d/OVMF_VARS.fd ]]; then
            OVMF_CODE=$d/OVMF_CODE.fd
            OVMF_VARS=$d/OVMF_VARS.fd
            return
        fi
        if [[ -f $d/OVMF_CODE_4M.fd && -f $d/OVMF_VARS_4M.fd ]]; then
            OVMF_CODE=$d/OVMF_CODE_4M.fd
            OVMF_VARS=$d/OVMF_VARS_4M.fd
            return
        fi
    done
    echo "run-qemu: could not find OVMF firmware; set OVMF_CODE and OVMF_VARS" >&2
    exit 1
}

find_firmware
mkdir -p "$OUT"

ESP="$OUT/esp.img"
LOG="$OUT/serial.log"
VARS="$OUT/vars.fd"

rm -f "$ESP"
dd if=/dev/zero of="$ESP" bs=1M count=64 status=none
mkfs.fat -F 16 "$ESP" >/dev/null
mmd -i "$ESP" ::/EFI ::/EFI/BOOT
mcopy -i "$ESP" "$APP" ::/EFI/BOOT/BOOTX64.EFI

for spec in "${FILES[@]}"; do
    host=${spec%%:*}
    dest=${spec#*:}
    if [[ $host == "$spec" || -z $dest ]]; then
        echo "run-qemu: --file expects HOST:ESP, got '$spec'" >&2
        exit 2
    fi
    if [[ ! -f $host ]]; then
        echo "run-qemu: file not found: $host" >&2
        exit 2
    fi
    # Create any missing target directories.
    dir=${dest%/*}
    if [[ -n $dir ]]; then
        partial=
        IFS='/' read -r -a parts <<< "$dir"
        for part in "${parts[@]}"; do
            [[ -z $part ]] && continue
            partial=$partial/$part
            mmd -i "$ESP" "::$partial" 2>/dev/null || true
        done
    fi
    mcopy -i "$ESP" "$host" "::$dest"
done

cp "$OVMF_VARS" "$VARS"
chmod u+w "$VARS"
rm -f "$LOG"

set +e
timeout "${QEMU_TIMEOUT:-45}" "$QEMU" \
    -machine q35 -m 256 -no-reboot -net none -display none \
    -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE" \
    -drive "if=pflash,format=raw,file=$VARS" \
    -drive "format=raw,file=$ESP" \
    -serial "file:$LOG" >/dev/null 2>&1
QEMU_RC=$?
set -e

if grep -a -q -- "$EXPECT" "$LOG"; then
    echo "run-qemu: PASS ($EXPECT)"
    [[ $KEEP == 1 ]] || true
    exit 0
fi

echo "run-qemu: FAIL (qemu exit $QEMU_RC), expected: $EXPECT" >&2
echo "run-qemu: serial log follows" >&2
if [[ -f $LOG ]]; then
    tail -c 4000 "$LOG" | tr -d '\000' >&2 || true
fi
exit 1
