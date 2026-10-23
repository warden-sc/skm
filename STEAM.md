# 스팀 출시 준비 (체크리스트)

크루세이더를 스팀에 올리기 위해 **이미 해 둔 것**과 **남은 것**을 정리한 문서입니다.
지금 빌드에는 Steamworks SDK 가 들어 있지 않습니다 — 아래 「남은 것」의 1번을 하면 업적이 그대로 스팀과 연결됩니다.

## 이미 해 둔 것

| 항목 | 위치 | 설명 |
| --- | --- | --- |
| 업적 11개 | `scripts/autoload/achievements.gd` | 달성 시 화면 알림 + `user://profile.cfg` 기록. `Engine.has_singleton("Steam")` 이면 `Steam.setAchievement(id)` · `storeStats()` 도 호출 |
| 버전 표기 | `project.godot` `config/version` · 타이틀 오른쪽 아래 · `export_presets.cfg` file/product_version | 스팀 빌드를 올릴 때마다 함께 올림 |
| 효과음 | `scripts/autoload/sfx.gd` · `assets/audio/sfx/` | 27가지 상황 43개 (Kenney CC0 — 크레딧 표기 의무 없음, README 「효과음」) |
| 설정 저장 | `user://profile.cfg` | 화면 흔들림 · 전체 화면 · 대사 · 음성 채팅 · 음량 4가지 |
| 난이도 3단계 + 한 방 상한 | `GameManager.DIFFICULTY_INFO` | 처음 하는 사람도 끝까지 갈 수 있게 노멀을 낮춤 |
| Windows 빌드 | `export_presets.cfg` "Windows Desktop" | 스팀 기본 대상 — **이 설정으로만 업로드** |
| 운영자 모드 분리 | `scripts/autoload/admin.gd` · "Windows (운영자)" 설정 | 개발자용 빌드(`admin_build`)에서만, 그것도 운영자 키 · 개발자 스팀 ID 가 맞을 때만. 켜져 있으면 업적 없음 |

### 업적 API 이름 (스팀웍스에 그대로 등록)

| API 이름 | 표시 이름 | 조건 |
| --- | --- | --- |
| `FIRST_BOSS` | 첫 토벌 | 1스테이지 보스(슬라임 킹) 토벌 |
| `STAGE_10` | 옥좌의 주인 | 10스테이지 클리어 |
| `STAGE_40` | 신화의 문턱 | 40스테이지 클리어 |
| `STAGE_70` | 태양을 넘어 | 70스테이지 클리어 |
| `STAGE_100` | 하늘의 끝 | 100스테이지(가브리엘) 클리어 |
| `GAME_CLEAR` | 멀티버스의 끝 | 최종장 보스 토벌 · 엔딩 |
| `HIDDEN_CLEAR` | 고대 용의 비늘 | 히든 보스 아르케 토벌 |
| `FIRST_MYTHIC` | 신화의 유산 | 신화 장비 처음 획득 |
| `ALL_TRIALS` | 네 가지 시련 | 보스방 해방 시련 4종(처치 · 봉인 코어 · 정예 · 제단)을 모두 이룸 |
| `CO_OP_BOSS` | 함께라면 | 멀티플레이 중 보스 토벌 |
| `HARD_CLEAR` | 베리하드 정복자 | 베리하드로 엔딩 |

업적 아이콘(64×64, 달성 / 미달성 2장씩)은 아직 없습니다.

## 남은 것

1. **Steamworks SDK 연결** — [GodotSteam](https://godotsteam.com) (GDExtension 판)을 `addons/` 에 넣고
   - `steam_appid.txt` (개발 중에만, 앱 ID) 를 실행 파일 옆에 둠
   - 시작할 때 `Steam.steamInitEx()` 호출 (예: `Achievements._ready()` 에서 `Engine.has_singleton("Steam")` 일 때)
   - 매 프레임 `Steam.run_callbacks()` (GodotSteam 설정의 자동 콜백을 켜면 생략)
2. **스팀웍스 파트너 계정 · 앱 등록** — 앱 크레딧(앱당 100달러), 세금 · 은행 정보, 앱 ID 발급
3. **스토어 페이지** — 캡슐 이미지(헤더 920×430 · 작은 캡슐 462×174 · 메인 1232×706 · 세로 748×896 · 라이브러리 600×900 / 3840×1240 / 로고), 스크린샷 5장 이상, 트레일러, 한국어 · 영어 설명, 연령 등급 설문
4. **업적 등록** — 위 표의 API 이름 그대로 + 아이콘
5. **빌드 업로드** — SteamPipe(`steamcmd` + `app_build.vdf`)로 Windows 빌드(`Crusader.exe` + `.pck`) 업로드, 실행 옵션 등록
6. **멀티플레이** — 지금은 IP · 포트 포워딩(UDP 24570) 방식. 스팀판은 `SteamMultiplayerPeer`(GodotSteam) 로 바꾸면 스팀 친구 초대 · 중계(포트 포워딩 불필요)가 됨 → `scripts/autoload/net.gd` 의 피어 생성 부분만 교체
7. **스팀 클라우드** — `user://save.json` · `user://profile.cfg` 를 자동 클라우드(스팀웍스 설정만으로 가능)에 등록
8. **스팀 덱** — 게임패드 조작(지금은 키보드 + 마우스 전용), 1280×800 화면 확인
9. **운영자 모드** — 개발자 스팀 ID(64비트)를 `Admin.DEV_STEAM_IDS` 에. 스팀에 올리는 빌드는 반드시 「Windows Desktop」 설정 (「Windows (운영자)」 빌드는 올리지 말 것)
10. **콘텐츠 마감** — 짧은 효과 음악(징글), 영어 번역(지금은 한국어만), 실제 사람의 플레이 테스트로 밸런스 확인
