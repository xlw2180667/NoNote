#!/bin/bash
# 采集 App Store 截图原图(每语言 6 张)到 AppStoreScreenshots/<lang>/。
#
#   ./tools/screenshots/capture_raw.sh                 # 全部 6 个语言
#   ./tools/screenshots/capture_raw.sh ja ko           # 只做这几个
#   DEVICE="iPhone 16 Plus" ./tools/screenshots/capture_raw.sh es
#
# 之后跑 tools/screenshots/make_captioned.py 加标语,再用 tools/asc/asc_upload.py 上传。
#
# 关键点:
# - 必须是 Debug 构建 —— 演示模式(-DemoData / -DemoScreen / -DemoPro)在 #if DEBUG 里。
# - 语言不改模拟器系统设置,而是每次启动传 -AppleLanguages / -AppleLocale,只影响本 App。
# - 状态栏统一 override 成 9:41 / 满信号 / 充电中,否则每张图右上角都不一样。
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEVICE="${DEVICE:-iPhone 16 Plus}"     # 6.7 吋档位;成品画布由 make_captioned.py 统一成 1284×2778
BUNDLE_ID="greenCross.NoDiary"
SCHEME="NoDiary"
OUT_ROOT="$REPO/AppStoreScreenshots"

ALL_LANGS=(en zh-Hans zh-Hant ja ko es)
if [ $# -gt 0 ]; then LANGS=("$@"); else LANGS=("${ALL_LANGS[@]}"); fi

# lang → AppleLocale
locale_for() {
  case "$1" in
    en)      echo "en_US" ;;
    zh-Hans) echo "zh_CN" ;;
    zh-Hant) echo "zh_TW" ;;
    ja)      echo "ja_JP" ;;
    ko)      echo "ko_KR" ;;
    es)      echo "es_ES" ;;
    *) echo "未知语言 $1" >&2; exit 1 ;;
  esac
}

# 每张图: 文件名|DemoScreen|外观
SHOTS=(
  "1-home|lastMonth|light"
  "2-flock|flock|light"
  "3-editor|editor|light"
  "4-stats|stats|light"
  "5-home-dark|lastMonth|dark"
  "6-privacy|lock|light"
)

echo "==> 设备 $DEVICE"
UDID=$(xcrun simctl list devices available | grep -F "$DEVICE (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
[ -n "$UDID" ] || { echo "找不到可用模拟器 '$DEVICE'"; exit 1; }
xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b

echo "==> 构建 Debug(演示模式需要 DEBUG)"
DERIVED="$REPO/build/screenshots"
xcodebuild -project "$REPO/NoNote.xcodeproj" -scheme "$SCHEME" -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$DERIVED" build >/dev/null
APP="$DERIVED/Build/Products/Debug-iphonesimulator/$SCHEME.app"
[ -d "$APP" ] || { echo "没找到构建产物 $APP"; exit 1; }

echo "==> 安装(先卸载:干净状态)"
# 必须先卸载。-DemoData 让 App 不再请求定位,但模拟器可能还挂着上一次未回答的定位授权弹窗——
# 它会一直浮在屏幕上盖住截图,即使 App 已被杀掉。实测 `privacy grant` 和 `privacy reset` 都清不掉,
# 只有卸载能。演示数据每次启动重建,所以卸载不会丢东西。
# (2026-08 就是漏了这步,把带弹窗的截图传上了 App Store Connect。)
xcrun simctl uninstall "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"

# 状态栏统一(9:41、满格信号、充电中),和已有的 en/zh-Hans 成品一致
xcrun simctl status_bar "$UDID" override \
  --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charging --batteryLevel 100

for lang in "${LANGS[@]}"; do
  loc=$(locale_for "$lang")
  out="$OUT_ROOT/$lang"
  mkdir -p "$out"
  echo "==> $lang ($loc)"
  for entry in "${SHOTS[@]}"; do
    IFS='|' read -r name screen appearance <<<"$entry"
    xcrun simctl ui "$UDID" appearance "$appearance" >/dev/null

    # 每张图都从干净状态起:关掉 App,清掉上一次留下的 UserDefaults 开关
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl launch "$UDID" "$BUNDLE_ID" \
      -AppleLanguages "($lang)" -AppleLocale "$loc" \
      -DemoData -DemoPro -dontShowAlert YES -DemoScreen "$screen" >/dev/null

    sleep 4    # 等演示数据落地 + 目标界面的 0.8s 延迟动画走完
    xcrun simctl io "$UDID" screenshot --type=png "$out/$name.png" >/dev/null
    echo "   $lang/$name.png ✓"
  done
done

xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl status_bar "$UDID" clear
xcrun simctl ui "$UDID" appearance light >/dev/null

echo "==> 完成。下一步:python3 tools/screenshots/make_captioned.py ${LANGS[*]}"
