#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
#   FontAny - Font Converter for MT Manager
#   Usage: fontany /path/to/fonts/folder
# ============================================================

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

OUT_DIR="/sdcard/FontAny"
TMP_DIR="$OUT_DIR/.tmp"

banner() {
    clear
cat << "EOF"
  ███████╗ ██████╗ ███╗   ██╗████████╗ █████╗ ███╗   ██╗██╗   ██╗
  ██╔════╝██╔═══██╗████╗  ██║╚══██╔══╝██╔══██╗████╗  ██║╚██╗ ██╔╝
  █████╗  ██║   ██║██╔██╗ ██║   ██║   ███████║██╔██╗ ██║ ╚████╔╝
  ██╔══╝  ██║   ██║██║╚██╗██║   ██║   ██╔══██║██║╚██╗██║  ╚██╔╝
  ██║     ╚██████╔╝██║ ╚████║   ██║   ██║  ██║██║ ╚████║   ██║
  ╚═╝      ╚═════╝ ╚═╝  ╚═══╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝
EOF
    echo -e "${CYAN}      ⚡ FontAny - MT Manager Converter ⚡${NC}\n"
}

# ---------- تثبيت المتطلبات ----------
check_deps() {
    local miss=()
    for p in zip file; do
        command -v "$p" >/dev/null 2>&1 || miss+=("$p")
    done
    command -v woff2_decompress >/dev/null 2>&1 || miss+=(woff2)
    [ ${#miss[@]} -gt 0 ] && pkg install -y "${miss[@]}" >/dev/null 2>&1
}

# ---------- تحويل لأي خط إلى TTF ----------
to_ttf() {
    local src="$1" out="$2"
    local ext=$(echo "${src##*.}" | tr 'A-Z' 'a-z')

    case "$ext" in
        ttf|otf|ttc)
            cp "$src" "$out"; return 0 ;;
        woff2)
            local tmp="$TMP_DIR/$(basename "$src")"
            cp "$src" "$tmp"
            (cd "$TMP_DIR" && woff2_decompress "$(basename "$src")" >/dev/null 2>&1)
            local produced="$TMP_DIR/${tmp%.woff2}.ttf"
            if [ -f "$produced" ]; then
                mv "$produced" "$out"
                rm -f "$tmp"
                return 0
            fi
            rm -f "$tmp" "$produced"
            return 1 ;;
        woff)
            python3 - "$src" "$out" <<'PY' >/dev/null 2>&1
import sys
from fontTools.ttLib import TTFont
f = TTFont(sys.argv[1])
f.flavor = None
f.save(sys.argv[2])
PY
            [ -f "$out" ] && return 0
            return 1 ;;
        *) return 1 ;;
    esac
}

# ---------- اسم الخط ----------
font_name() {
    local f="$1" n=""
    command -v fc-scan >/dev/null 2>&1 && \
        n=$(fc-scan --format "%{family}\n" "$f" 2>/dev/null | head -n1)
    [ -z "$n" ] && n=$(basename "$f" | sed -E 's/\.(ttf|otf|ttc|woff2?|TTF|OTF|WOFF2?)$//')
    echo "$n" | tr ' ' '_' | tr -d '/\\:*?"<>|'
}

# ---------- بناء MTZ ----------
build_mtz() {
    local font="$1" name="$2"
    local w="$TMP_DIR/mtz_$$"
    rm -rf "$w"
    mkdir -p "$w/fonts" "$w/META-INF/com/mt"

    for n in Regular Bold Italic BoldItalic Light Medium; do
        cp "$font" "$w/fonts/Roboto-$n.ttf"
    done

    cat > "$w/META-INF/com/mt/theme.info" << INFO
name=FontAny - ${name}
author=FontAny
version=1.0
type=font
INFO

    cat > "$w/description.xml" << XML
<?xml version="1.0" encoding="UTF-8"?>
<theme>
    <name>FontAny - ${name}</name>
    <author>FontAny</author>
    <version>1.0</version>
    <type>font</type>
</theme>
XML

    local mtz="$OUT_DIR/${name}.mtz"
    (cd "$w" && zip -rq "$mtz" .)
    rm -rf "$w"
    echo "$mtz"
}

# ---------- معالجة ----------
process() {
    local dir="${1%/}"
    [ ! -d "$dir" ] && { echo -e "${RED}✗ المجلد غير موجود: $dir${NC}"; exit 1; }

    mkdir -p "$OUT_DIR" "$TMP_DIR"

    mapfile -t files < <(find "$dir" -maxdepth 3 -type f \
        \( -iname "*.ttf" -o -iname "*.otf" -o -iname "*.ttc" \
        -o -iname "*.woff" -o -iname "*.woff2" \) 2>/dev/null)

    [ ${#files[@]} -eq 0 ] && { echo -e "${RED}✗ لا توجد خطوط${NC}"; exit 1; }

    echo -e "${CYAN}[*] ${#files[@]} خط في: $dir${NC}\n"

    local i=1 ok=0
    for f in "${files[@]}"; do
        local name=$(font_name "$f")
        local ttf="$TMP_DIR/${name}.ttf"

        printf "${YELLOW}[%d/%d]${NC} %s → " "$i" "${#files[@]}" "$(basename "$f")"

        if to_ttf "$f" "$ttf"; then
            build_mtz "$ttf" "$name" >/dev/null
            echo -e "${GREEN}✓ ${name}.mtz${NC}"
            rm -f "$ttf"
            ((ok++))
        else
            echo -e "${RED}✗ فشل${NC}"
        fi
        ((i++))
    done

    rm -rf "$TMP_DIR"
    echo -e "\n${GREEN}✓ تم إنشاء $ok ملف MTZ في:${NC} ${CYAN}$OUT_DIR${NC}\n"
}

# ---------- Main ----------
banner
[ $# -lt 1 ] && {
    echo -e "${YELLOW}الاستخدام:${NC} fontany <مسار_مجلد_الخطوط>"
    echo -e "${YELLOW}مثال:${NC} fontany /sdcard/Download/Fonts\n"
    exit 0
}

check_deps
process "$1"
