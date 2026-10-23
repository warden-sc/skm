# 스팀 출시 준비 (체크리스트)

크루세이더를 스팀에 올리기 위해 **이미 해 둔 것**과 **남은 것**을 정리한 문서입니다.
게임 코드는 GodotSteam 을 받을 준비가 되어 있습니다 (`SteamApi` 오토로드) — `addons/godotsteam` 이 들어오면 시작할 때 스팀에 연결하고, 업적 · 개발자 스팀 ID 가 그대로 이어집니다. 없으면(웹 · 지금 빌드) 스팀 없이 그대로 동작.

## 이미 해 둔 것

| 항목 | 위치 | 설명 |
| --- | --- | --- |
| 스팀 연결 | `scripts/autoload/steam_api.gd` (`SteamApi`) | GodotSteam 이 있으면 시작할 때 `steamInitEx`(버전마다 다른 인자도 맞춤) · 매 프레임 `run_callbacks` · `is_running()` / `get_steam_id()` / `set_achievement()`. 앱 ID 는 `SteamApi.APP_ID` (0 이면 `steam_appid.txt`) |
| 업적 11개 | `scripts/autoload/achievements.gd` | 달성 시 화면 알림 + `user://profile.cfg` 기록 + 스팀에 연결돼 있으면 `SteamApi.set_achievement(id)` |
| 창 제목 | `Profile.WINDOW_TITLE` | 「크루세이더 (Crusader)」 — `config/name` 은 저장 폴더 이름이라 그대로 둠 |
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
| `ALL_TRIALS` | 일곱 가지 시련 | 보스방 해방 시련 7종(처치 · 파괴 · 정예 · 수호 · 수집 · 점화 · 버티기)을 모두 이룸 |
| `CO_OP_BOSS` | 함께라면 | 멀티플레이 중 보스 토벌 |
| `HARD_CLEAR` | 베리하드 정복자 | 베리하드로 엔딩 |

업적 아이콘(64×64, 달성 / 미달성 2장씩)은 아직 없습니다.

## 남은 것

### 1. GodotSteam 을 프로젝트에 넣기 (지금 할 것)

- **GDExtension 판**을 씁니다 (에디터 안 AssetLib 에서 「GodotSteam GDExtension」 → 설치하면 `addons/godotsteam/` 이 생김). 이 프로젝트는 **Godot 4.3** 이므로 4.3 에서 쓸 수 있는 판인지 확인.
  - GodotSteam 「사전 빌드 에디터」(모듈 판)를 받았다면: 그 에디터로 열고, **내보내기 템플릿도 GodotSteam 것**을 써야 스팀이 들어간 exe 가 나옴. 둘 중 하나만 — GDExtension 판이 관리가 쉬움.
- `addons/godotsteam/` 폴더를 저장소에 올려 주면(또는 zip 으로 전달) 빌드에 함께 들어갑니다. Windows 빌드 옆에 `steam_api64.dll` 이 같이 나와야 함 (GDExtension 이 자동으로 복사).
- 시험: 프로젝트 폴더(에디터 실행) 또는 exe 옆에 `steam_appid.txt` 를 만들고 **480**(스팀 시험용 앱 Spacewar)을 한 줄 적은 뒤, 스팀을 켠 상태에서 실행 → 출력 창에 `[SteamApi] 스팀 연결됨 (내 닉네임)`. 이때 `SteamApi.get_steam_id()` 로 내 스팀 ID(64비트)를 확인해 `Admin.DEV_STEAM_IDS` 에 넣음.
- 웹 빌드는 GodotSteam 이 없으므로 그대로 (스팀 없이 동작).

### 2. 스팀웍스 · 스토어

1. **파트너 계정 · 앱 등록** — 앱 크레딧(앱당 100달러), 세금(W-8BEN) · 은행 정보, 신원 확인 → 앱 ID 발급 → `SteamApi.APP_ID` 에 넣고 `steam_appid.txt` 는 배포 빌드에서 뺌
2. **스토어 페이지** — 캡슐 이미지(헤더 920×430 · 작은 캡슐 462×174 · 메인 1232×706 · 세로 748×896 · 라이브러리 600×900 / 3840×1240 / 로고 · 배경), 스크린샷 5장 이상(1920×1080), 트레일러(권장), 한국어 · 영어 설명, 태그, **콘텐츠 설문**(폭력 수위 · AI 생성 콘텐츠 공개 — 배경음은 Suno 로 만들었으므로 「AI 생성 콘텐츠」에 표시), 시스템 요구 사항
3. **「출시 예정」 공개** — 출시 2주 이상 전에 공개해야 함 (위시리스트 모으기). 스토어 페이지 · 빌드는 각각 밸브 검토(보통 영업일 3~5일)
4. **업적 등록** — 아래 표의 API 이름 그대로 + 아이콘 64×64 (달성 / 미달성 2장씩 × 11 — 아직 없음)
5. **빌드 업로드** — SteamPipe(`steamcmd` + `app_build.vdf` + depot)로 「Windows Desktop」 빌드(`Crusader.exe` + `.pck` + `steam_api64.dll`) 업로드, 실행 옵션 등록, 기본 브랜치에 적용
6. **가격** — 기본 가격 · 지역별 가격(스팀 추천값), 출시 할인 여부
7. **스팀 클라우드** — 「자동 클라우드」에 저장 파일 등록: Windows `%APPDATA%/Godot/app_userdata/Sefirah-like Topdown Action/` 의 `save.json` · `profile.cfg`

### 3. 게임 쪽 (출시 전에 하면 좋은 것)

1. **멀티플레이를 스팀으로** — 지금은 IP · 포트 포워딩(UDP 24570). GodotSteam 의 `SteamMultiplayerPeer` 로 바꾸면 스팀 친구 초대 · 중계(포트 포워딩 불필요) → `scripts/autoload/net.gd` 의 피어 만드는 부분만 교체
2. **게임패드 · 스팀 덱** — 지금은 키보드 + 마우스 전용. 게임패드 조작(조준 = 오른쪽 스틱)과 1280×800 화면 확인이 있으면 「스팀 덱 확인됨」 신청 가능
3. **영어 번역** — 지금은 한국어만 (스팀 이용자 대부분이 영어권)
4. **업적 아이콘** · **스토어용 스크린샷/트레일러** (게임 화면 녹화)
5. **실제 사람의 플레이 테스트** — 난이도 · 골드(값 2배 조정 후) · 해방 시련 시간 확인
6. **크래시 · 성능** — 저사양 PC, 다른 해상도 · 전체 화면 전환

### 4. 권리 · 표기

- 배경음: Suno 유료 플랜(Pro/Premier)으로 만든 곡 — 상업적 이용 가능 (무료 플랜으로 만든 곡은 안 됨). 형식 변환은 상관없음
- 효과음: Kenney CC0 (표기 의무 없음, 크레딧에 넣으면 좋음)
- 글꼴: Galmuri (SIL OFL — `assets/fonts/Galmuri-OFL-LICENSE.txt` 를 함께 배포)
- Godot 엔진: MIT — 크레딧/라이선스 문구 포함 권장
- 음성 채팅이 있으므로 개인정보(마이크) 사용을 스토어 설명에 적어 두면 좋음

### 5. 운영자 모드

- 개발자 스팀 ID(64비트)를 `Admin.DEV_STEAM_IDS` 에. 스팀에 올리는 빌드는 반드시 「Windows Desktop」 설정 (「Windows (운영자)」 빌드는 올리지 말 것)
