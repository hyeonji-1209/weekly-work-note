# weekly-work-note

매주 금요일 17:00, 지난 7일간 `~/work` 저장소들의 내 커밋을 모아 주간업무 초안을 만들어
Apple 메모 **주간업무** 폴더에 기록합니다 (같은 주 메모가 있으면 덮어쓰기, repo에 md는 남기지 않음).
커밋 메시지 나열이 아니라 diff를 `claude` CLI로 요약해 실제 작업 내용을 적습니다
(claude 미설치·요약 실패 시 커밋 메시지 나열로 폴백).

- `./weekly_note.sh` — 지금 바로 초안 생성 (`WEEKLY_DAYS=14 ./weekly_note.sh` 로 기간 조절)
- `./install.sh` / `./install.sh uninstall` — 자동 실행 등록/해제 (launchd)
- 스캔 폴더 변경: `weekly_note.sh`의 `REPO_ROOTS`
- 로그: `notes/launchd.log`
