#!/data/data/com.termux/files/usr/bin/bash
pkg install -y zip file woff2 >/dev/null 2>&1
[ ! -d "/sdcard/Download" ] && termux-setup-storage && sleep 3
D="$(cd "$(dirname "$0")" && pwd)"
cp "$D/fontany" "$PREFIX/bin/fontany"
chmod +x "$PREFIX/bin/fontany"
mkdir -p /sdcard/FontAny
echo -e "\033[1;32m✓ تم التثبيت. استخدم: fontany /path/to/fonts\033[0m"
