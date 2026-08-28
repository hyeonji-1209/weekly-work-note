#!/bin/bash
# launchd 등록/해제: ./install.sh | ./install.sh uninstall
cd "$(dirname "$0")"
PLIST=~/Library/LaunchAgents/com.hyeonji.weekly-work-note.plist
if [ "${1:-}" = "uninstall" ]; then
  launchctl bootout gui/$(id -u) "$PLIST" 2>/dev/null; rm -f "$PLIST"; echo "해제 완료"; exit
fi
cp com.hyeonji.weekly-work-note.plist "$PLIST"
launchctl bootout gui/$(id -u) "$PLIST" 2>/dev/null
launchctl bootstrap gui/$(id -u) "$PLIST" && echo "등록 완료: 매주 금요일 17:00 실행"
