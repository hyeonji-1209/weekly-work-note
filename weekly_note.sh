#!/bin/bash
# 주간업무 초안 생성기
# - ~/work 아래 git 저장소에서 지난 7일간 내 커밋을 모아 마크다운 초안 작성
# - notes/YYYY-Www.md 로 저장 + Apple 메모(주간업무 폴더)에 새 메모 생성
set -u
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

REPO_ROOTS=("$HOME/work")            # 스캔할 상위 폴더들 (필요하면 추가)
AUTHOR="${WEEKLY_AUTHOR:-$(git config --global user.email)}"
DAYS="${WEEKLY_DAYS:-7}"
NOTES_DIR="$(cd "$(dirname "$0")" && pwd)/notes"
NOTES_FOLDER="주간업무"                # Apple 메모 폴더명

START=$(date -v-"$DAYS"d +%Y-%m-%d)
END=$(date +%Y-%m-%d)
WEEK=$(date +%G-W%V)
TITLE="주간업무 $WEEK ($START ~ $END)"
OUT="$NOTES_DIR/$WEEK.md"
mkdir -p "$NOTES_DIR"

body=""
total=0
for root in "${REPO_ROOTS[@]}"; do
  for d in "$root"/*/; do
    [ -d "$d/.git" ] || continue
    log=$(git -C "$d" log --all --no-merges --since="$DAYS days ago" \
          --author="$AUTHOR" --date=format:%m/%d --pretty='- [%ad] %s' 2>/dev/null)
    [ -n "$log" ] || continue
    n=$(printf '%s\n' "$log" | wc -l | tr -d ' ')
    total=$((total + n))
    body+="### $(basename "$d") ($n commits)"$'\n'"$log"$'\n\n'
  done
done
[ -n "$body" ] || body="- (지난 ${DAYS}일간 커밋 없음)"$'\n\n'

cat > "$OUT" <<MD
# $TITLE

## 이번 주 한 일 (커밋 기준 자동 수집, 총 ${total}건)

$body## 다음 주 계획
- 

## 이슈 / 공유사항
- 

---
_생성: $(date '+%Y-%m-%d %H:%M') · weekly_note.sh_
MD

echo "saved: $OUT"

# Apple 메모에 기록 (마크다운 → 간단 HTML)
html=$(sed -E \
  -e 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' \
  -e 's/^# (.*)$/<h1>\1<\/h1>/' \
  -e 's/^## (.*)$/<h2>\1<\/h2>/' \
  -e 's/^### (.*)$/<h3>\1<\/h3>/' \
  -e 's/^- (.*)$/• \1<br>/' \
  -e 's/^---$/<hr>/' \
  -e 's/^_(.*)_$/<i>\1<\/i>/' \
  -e 's/^$/<br>/' "$OUT" | sed -E '/^<h[123]>|<hr>|<br>$/!s/$/<br>/')

osascript - "$NOTES_FOLDER" "$TITLE" "$html" <<'AS'
on run {folderName, noteTitle, noteBody}
  tell application "Notes"
    tell account 1
      if not (exists folder folderName) then make new folder with properties {name:folderName}
      tell folder folderName
        make new note with properties {name:noteTitle, body:noteBody}
      end tell
    end tell
  end tell
end run
AS
echo "Apple 메모 '$NOTES_FOLDER/$TITLE' 생성 완료"
