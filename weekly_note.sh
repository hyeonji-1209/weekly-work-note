#!/bin/bash
# 주간업무 초안 생성기
# - ~/work 아래 git 저장소에서 지난 7일간 내 커밋을 모아 마크다운 초안 작성
# - 커밋 메시지만 나열하지 않고, diff를 claude CLI로 요약해 실제 작업 내용을 적는다
#   (claude 미설치·요약 실패 시 커밋 메시지 나열로 폴백)
# - 결과는 Apple 메모(주간업무 폴더)에만 기록한다 — 같은 주 메모가 있으면 덮어쓰고, 없으면 생성.
#   repo에는 md 파일을 남기지 않는다 (notes/는 launchd 로그 전용).
set -u
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

REPO_ROOTS=("$HOME/work")            # 스캔할 상위 폴더들 (필요하면 추가)
AUTHOR="${WEEKLY_AUTHOR:-$(git config --global user.email)}"
DAYS="${WEEKLY_DAYS:-7}"
NOTES_DIR="$(cd "$(dirname "$0")" && pwd)/notes"   # launchd 로그 전용 (plist가 여기에 기록)
NOTES_FOLDER="주간업무"                # Apple 메모 폴더명

# 기준일 — 보통 오늘. 놓친 주를 백필하려면 WEEKLY_REF=2026-09-04 처럼 그 주의 금요일을 준다.
REF="${WEEKLY_REF:-$(date +%Y-%m-%d)}"
START=$(date -j -v-"$DAYS"d -f %Y-%m-%d "$REF" +%Y-%m-%d)
END="$REF"
WEEK=$(date -j -f %Y-%m-%d "$REF" +%G-W%V)
TITLE="주간업무 $WEEK ($START ~ $END)"
mkdir -p "$NOTES_DIR"
OUT=$(mktemp -t weekly-note)           # 메모 변환용 임시 md — 종료 시 삭제
trap 'rm -f "$OUT"' EXIT

CLAUDE_BIN="$(command -v claude || true)"
PATCH_LIMIT="${WEEKLY_PATCH_LIMIT:-8000}"   # 커밋당 claude에 넘길 diff 최대 바이트
SUMMARY_PROMPT='아래는 한 저장소에서 지난 주에 작성된 커밋들이다(메시지 + diff).
개발팀 주간업무일지에 넣을 요약을 한국어 마크다운으로 작성하라.

형식(이 불릿들만 출력, 서두·맺음말·코드펜스 금지):
- [MM/DD] 실제 작업을 요약한 한 줄 제목 — `원래 커밋 메시지 제목`
  - 실제로 무엇을 왜 바꿨는지 하위 불릿 1~4개 (커밋 규모에 비례)

규칙:
- 커밋 메시지를 베끼지 말고 diff에서 실제 변경 내용을 파악해서 써라.
- 버그 수정은 가능하면 원인까지 한 줄로. 기능·정책 변경은 무엇이 어떻게 바뀌었는지.
- 최신 커밋이 먼저 오게 날짜 역순으로.'

# 저장소 하나의 내 커밋 diff를 모아 claude로 요약. 실패하면 빈 출력.
summarize_repo() { # $1=repo dir
  [ -n "$CLAUDE_BIN" ] || return 1
  local dump="" h
  while IFS= read -r h; do
    [ -n "$h" ] || continue
    dump+=$(git -C "$1" show "$h" --date=format:%m/%d \
              --pretty='===== 커밋 [%ad] %s%n%b' --stat --patch --unified=1 \
              -- . ':(exclude)*.lock' ':(exclude)*lock.json' 2>/dev/null | head -c "$PATCH_LIMIT")
    dump+=$'\n\n'
  done < <(git -C "$1" log --all --no-merges --since="$START 00:00" --until="$END 23:59" \
             --author="$AUTHOR" --pretty=%H 2>/dev/null)
  [ -n "$dump" ] || return 1
  printf '%s' "$dump" | "$CLAUDE_BIN" -p "$SUMMARY_PROMPT" 2>/dev/null
}

body=""
total=0
for root in "${REPO_ROOTS[@]}"; do
  for d in "$root"/*/; do
    [ -d "$d/.git" ] || continue
    log=$(git -C "$d" log --all --no-merges --since="$START 00:00" --until="$END 23:59" \
          --author="$AUTHOR" --date=format:%m/%d --pretty='- [%ad] %s' 2>/dev/null)
    [ -n "$log" ] || continue
    n=$(printf '%s\n' "$log" | wc -l | tr -d ' ')
    total=$((total + n))
    summary=$(summarize_repo "$d" || true)
    [ -n "$summary" ] || summary="$log"   # 요약 실패 시 커밋 메시지 나열로 폴백
    body+="### $(basename "$d") ($n commits)"$'\n'"$summary"$'\n\n'
  done
done
[ -n "$body" ] || body="- (지난 ${DAYS}일간 커밋 없음)"$'\n\n'

cat > "$OUT" <<MD
# $TITLE

## 이번 주 한 일 (커밋 diff 분석 자동 수집, 총 ${total}건)

$body## 다음 주 계획
- 

## 이슈 / 공유사항
- 

---
_생성: $(date '+%Y-%m-%d %H:%M') · weekly_note.sh_
MD

# Apple 메모에 기록 (마크다운 → 간단 HTML)
html=$(sed -E \
  -e 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' \
  -e 's/^# (.*)$/<h1>\1<\/h1>/' \
  -e 's/^## (.*)$/<h2>\1<\/h2>/' \
  -e 's/^### (.*)$/<h3>\1<\/h3>/' \
  -e 's/^ +- (.*)$/\&nbsp;\&nbsp;\&nbsp;\&nbsp;◦ \1<br>/' \
  -e 's/^- (.*)$/• \1<br>/' \
  -e 's/^---$/<hr>/' \
  -e 's/^_(.*)_$/<i>\1<\/i>/' \
  -e 's/^$/<br>/' "$OUT" | sed -E '/^<h[123]>|<hr>|<br>$/!s/$/<br>/')

# 빈 본문으로 기존 메모를 덮어쓰는 사고 방지
[ -n "$html" ] || { echo "본문 생성 실패 — 메모를 건드리지 않고 종료" >&2; exit 1; }

# osascript 실패(-1743 자동화 권한 거부 등)를 그대로 성공처럼 넘기지 않는다
osascript - "$NOTES_FOLDER" "$TITLE" "$html" <<'AS' || { echo "Apple 메모 기록 실패 — 시스템 설정 > 개인정보 보호 및 보안 > 자동화에서 Notes 권한 확인 필요" >&2; exit 1; }
on run {folderName, noteTitle, noteBody}
  tell application "Notes"
    tell account 1
      if not (exists folder folderName) then make new folder with properties {name:folderName}
      tell folder folderName
        -- 같은 주에 다시 돌리면 새 메모를 만들지 않고 기존 메모를 덮어쓴다
        if exists note noteTitle then
          set body of note noteTitle to noteBody
        else
          make new note with properties {name:noteTitle, body:noteBody}
        end if
      end tell
    end tell
  end tell
end run
AS
echo "Apple 메모 '$NOTES_FOLDER/$TITLE' 기록 완료"
