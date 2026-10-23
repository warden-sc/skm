class_name GateTrials
## 보스방 해방 시련 — 스테이지마다 그 스테이지 컨셉에 맞춘 시련 (StageManager 가 씀).
## 종류(StageManager.GateTrial):
##   KILL       처치      — 사냥터 몬스터를 목표 수만큼
##   SEAL_CORES 파괴      — 사냥터 곳곳의 물건(결정 · 관 · 알 · 우상 …)을 부숨. 체력 = 그 스테이지 몬스터 × hp
##   ELITE      정예      — 그 스테이지 몬스터 중 하나(elite)가 크고 강하게, 이름(title)을 달고 나옴
##   ALTAR      수호      — 원 안에서 time 초 버팀 (원 밖이면 멈춤)
##   COLLECT    수집      — 사냥터에 흩어진 물건 count 개를 주움 (닿으면 주워짐)
##   IGNITE     점화      — 사냥터의 자리 count 곳에 잠깐(IGNITE_TIME) 서 있으면 불이 켜짐 · 종이 울림
##   SURVIVE    버티기    — 몬스터가 더 많이 · 더 빨리 몰려오는 동안 time 초 버팀 (살아 있는 동안만 셈)
## 항목: type · title(시련 이름) · goal(안내 문구) · object(진행 글에 쓰는 이름) · count · time · color · elite(몬스터 씬 이름) · hp(파괴 물건 체력 배율)
## 1~2스테이지와 튜토리얼은 처치.

const KILL := 0
const SEAL_CORES := 1
const ELITE := 2
const ALTAR := 3
const COLLECT := 4
const IGNITE := 5
const SURVIVE := 6

const DEFAULTS := {"type": KILL, "title": "몬스터 처치", "goal": "", "object": "", "count": 3, "time": 18.0, "color": Color(0.8, 0.55, 1.0), "elite": "", "hp": 7.0}

const TABLE := {
	3: {"type": SEAL_CORES, "title": "원소 결정 파괴", "goal": "유적에 박힌 원소 결정 %d개를 부수세요", "object": "원소 결정", "count": 4, "color": Color(0.5, 0.9, 1.0)},
	4: {"type": COLLECT, "title": "생명의 씨앗", "goal": "숲에 떨어진 생명의 씨앗 %d개를 모으세요", "object": "생명의 씨앗", "count": 5, "color": Color(0.55, 1.0, 0.45)},
	5: {"type": IGNITE, "title": "성의 횃불", "goal": "어둠의 성 곳곳의 횃불 %d개를 밝히세요", "object": "횃불", "count": 4, "color": Color(1.0, 0.65, 0.3)},
	6: {"type": ELITE, "title": "오크 족장", "goal": "요새를 지키는 오크 족장을 쓰러뜨리세요", "elite": "orc_warrior", "color": Color(1.0, 0.75, 0.3)},
	7: {"type": SEAL_CORES, "title": "봉인된 관", "goal": "묘지의 봉인된 관 %d개를 부수세요", "object": "관", "count": 3, "color": Color(0.7, 0.55, 1.0)},
	8: {"type": SEAL_CORES, "title": "비룡의 알", "goal": "둥지의 비룡 알 %d개를 깨뜨리세요", "object": "비룡의 알", "count": 4, "hp": 5.0, "color": Color(1.0, 0.55, 0.35)},
	9: {"type": ALTAR, "title": "마계의 문 봉인", "goal": "봉인진 안에서 %d초 버텨 마계의 문을 닫으세요", "object": "마계의 문 봉인", "time": 20.0, "color": Color(1.0, 0.45, 0.85)},
	10: {"type": ELITE, "title": "근위대장", "goal": "버려진 왕궁의 근위대장을 쓰러뜨리세요", "elite": "royal_guard", "color": Color(1.0, 0.85, 0.4)},
	11: {"type": SEAL_CORES, "title": "실험 배양조", "goal": "연구소의 실험 배양조 %d개를 부수세요", "object": "배양조", "count": 3, "color": Color(0.5, 1.0, 0.5)},
	12: {"type": SEAL_CORES, "title": "마력 동력로", "goal": "공장의 마력 동력로 %d개를 멈추세요", "object": "동력로", "count": 3, "color": Color(0.45, 0.7, 1.0)},
	13: {"type": IGNITE, "title": "신전의 등불", "goal": "가라앉은 신전의 등불 %d개를 밝히세요", "object": "등불", "count": 4, "color": Color(0.4, 1.0, 0.9)},
	14: {"type": SURVIVE, "title": "시간의 틈", "goal": "시간의 틈이 닫힐 때까지 %d초 버티세요", "object": "시간의 틈", "time": 35.0, "color": Color(1.0, 0.9, 0.5)},
	15: {"type": SEAL_CORES, "title": "마법 거울", "goal": "미궁의 마법 거울 %d개를 깨세요", "object": "마법 거울", "count": 4, "hp": 5.5, "color": Color(0.85, 0.9, 1.0)},
	16: {"type": COLLECT, "title": "그리핀의 깃털", "goal": "봉우리에 흩날린 그리핀의 깃털 %d개를 모으세요", "object": "깃털", "count": 5, "color": Color(1.0, 0.95, 0.8)},
	17: {"type": SEAL_CORES, "title": "감옥의 사슬", "goal": "거인을 묶은 사슬 기둥 %d개를 끊으세요", "object": "사슬 기둥", "count": 3, "color": Color(0.75, 0.75, 0.8)},
	18: {"type": ELITE, "title": "광대 단장", "goal": "인형 극장의 광대 단장을 쓰러뜨리세요", "elite": "jester_doll", "color": Color(1.0, 0.5, 0.7)},
	19: {"type": IGNITE, "title": "등대의 불", "goal": "폭풍 속 등대 %d곳에 불을 밝히세요", "object": "등대", "count": 3, "color": Color(1.0, 0.95, 0.45)},
	20: {"type": SEAL_CORES, "title": "봉인된 마도서", "goal": "탑에 흩어진 봉인된 마도서 %d권을 찢으세요", "object": "마도서", "count": 3, "color": Color(0.75, 0.5, 1.0)},
	21: {"type": IGNITE, "title": "톱니 장치", "goal": "멈춘 톱니 장치 %d개를 다시 돌리세요", "object": "톱니 장치", "count": 4, "color": Color(0.95, 0.75, 0.4)},
	22: {"type": SURVIVE, "title": "모래 폭풍", "goal": "모래 폭풍이 지나갈 때까지 %d초 버티세요", "object": "모래 폭풍", "time": 35.0, "color": Color(1.0, 0.85, 0.5)},
	23: {"type": SEAL_CORES, "title": "피의 성배", "goal": "성 곳곳의 피의 성배 %d개를 깨뜨리세요", "object": "성배", "count": 3, "color": Color(1.0, 0.3, 0.35)},
	24: {"type": ALTAR, "title": "해독의 샘", "goal": "해독의 샘 곁에서 %d초 버텨 늪을 정화하세요", "object": "해독의 샘 정화", "time": 18.0, "color": Color(0.5, 1.0, 0.6)},
	25: {"type": IGNITE, "title": "해와 달의 제단", "goal": "해와 달의 제단 %d곳을 밝히세요", "object": "제단", "count": 4, "color": Color(1.0, 0.85, 0.45)},
	26: {"type": SEAL_CORES, "title": "얼음 수정", "goal": "궁전을 얼린 얼음 수정 %d개를 깨세요", "object": "얼음 수정", "count": 4, "hp": 5.5, "color": Color(0.6, 0.9, 1.0)},
	27: {"type": IGNITE, "title": "심연의 횃불", "goal": "어둠을 밀어낼 횃불 %d개를 밝히세요", "object": "횃불", "count": 4, "color": Color(0.6, 0.85, 1.0)},
	28: {"type": SEAL_CORES, "title": "공허의 알집", "goal": "둥지의 공허 알집 %d개를 터뜨리세요", "object": "알집", "count": 3, "color": Color(0.7, 0.4, 1.0)},
	29: {"type": COLLECT, "title": "꿈의 조각", "goal": "흩어진 꿈의 조각 %d개를 모으세요", "object": "꿈의 조각", "count": 5, "color": Color(1.0, 0.65, 0.95)},
	30: {"type": IGNITE, "title": "정령석", "goal": "잠든 정령석 %d개를 깨우세요", "object": "정령석", "count": 4, "color": Color(0.6, 1.0, 0.75)},
	31: {"type": SURVIVE, "title": "협곡의 돌풍", "goal": "협곡의 돌풍이 잦아들 때까지 %d초 버티세요", "object": "돌풍", "time": 30.0, "color": Color(0.7, 1.0, 0.9)},
	32: {"type": SEAL_CORES, "title": "대지 수정", "goal": "균열에서 솟은 대지 수정 %d개를 깨세요", "object": "대지 수정", "count": 4, "hp": 5.5, "color": Color(0.85, 0.65, 0.4)},
	33: {"type": IGNITE, "title": "얼음 위 모닥불", "goal": "얼어붙은 호수에 모닥불 %d개를 피우세요", "object": "모닥불", "count": 4, "color": Color(1.0, 0.6, 0.3)},
	34: {"type": SEAL_CORES, "title": "용암 분출구", "goal": "화산의 용암 분출구 %d개를 막으세요", "object": "분출구", "count": 3, "color": Color(1.0, 0.45, 0.2)},
	35: {"type": ELITE, "title": "원한의 영혼", "goal": "용의 묘지를 떠도는 원한의 영혼을 잠재우세요", "elite": "grudge_soul", "color": Color(0.75, 0.55, 1.0)},
	36: {"type": ALTAR, "title": "법정의 심판대", "goal": "심판대 위에서 %d초 동안 심판을 견디세요", "object": "심판", "time": 20.0, "color": Color(1.0, 0.9, 0.55)},
	37: {"type": SEAL_CORES, "title": "타락한 우상", "goal": "타락한 신전의 우상 %d개를 부수세요", "object": "우상", "count": 3, "color": Color(0.85, 0.35, 0.4)},
	38: {"type": ELITE, "title": "청동 백인대장", "goal": "해안을 지키는 청동 백인대장을 쓰러뜨리세요", "elite": "bronze_soldier", "color": Color(1.0, 0.7, 0.35)},
	39: {"type": COLLECT, "title": "아리아드네의 실타래", "goal": "미궁에 떨어진 실타래 %d개를 모으세요", "object": "실타래", "count": 4, "color": Color(1.0, 0.4, 0.4)},
	40: {"type": COLLECT, "title": "헤르메스의 편지", "goal": "구름 위에 흩어진 편지 %d통을 모으세요", "object": "편지", "count": 5, "color": Color(1.0, 1.0, 0.85)},
	41: {"type": IGNITE, "title": "성화대", "goal": "늪가의 성화대 %d개에 불을 붙이세요", "object": "성화대", "count": 4, "color": Color(1.0, 0.6, 0.25)},
	42: {"type": COLLECT, "title": "양털 뭉치", "goal": "동굴에 흩어진 양털 뭉치 %d개를 모으세요", "object": "양털", "count": 5, "color": Color(0.95, 0.95, 0.9)},
	43: {"type": COLLECT, "title": "카론의 은화", "goal": "명계의 강을 건널 은화 %d닢을 모으세요", "object": "은화", "count": 5, "color": Color(0.8, 0.85, 0.95)},
	44: {"type": SURVIVE, "title": "해협의 소용돌이", "goal": "소용돌이가 잠잠해질 때까지 %d초 버티세요", "object": "소용돌이", "time": 35.0, "color": Color(0.45, 0.75, 1.0)},
	45: {"type": KILL, "title": "투기장 연승", "goal": "투기장의 도전자 %d명을 쓰러뜨리세요"},
	46: {"type": SEAL_CORES, "title": "거미 알주머니", "goal": "신전의 거미 알주머니 %d개를 터뜨리세요", "object": "알주머니", "count": 4, "hp": 5.0, "color": Color(0.85, 0.85, 0.8)},
	47: {"type": SEAL_CORES, "title": "괴물의 알", "goal": "둥지의 괴물 알 %d개를 깨뜨리세요", "object": "괴물의 알", "count": 4, "hp": 5.0, "color": Color(0.6, 0.9, 0.45)},
	48: {"type": ELITE, "title": "네메아의 사자", "goal": "시련장의 네메아의 사자를 쓰러뜨리세요", "elite": "lion_cub", "color": Color(1.0, 0.8, 0.35)},
	49: {"type": SEAL_CORES, "title": "쇠사슬 말뚝", "goal": "바위산의 쇠사슬 말뚝 %d개를 뽑으세요", "object": "말뚝", "count": 3, "color": Color(0.7, 0.7, 0.75)},
	50: {"type": IGNITE, "title": "용광로", "goal": "대장간의 용광로 %d곳에 불을 지피세요", "object": "용광로", "count": 4, "color": Color(1.0, 0.55, 0.2)},
	51: {"type": IGNITE, "title": "청동 징", "goal": "호숫가의 청동 징 %d개를 울리세요", "object": "청동 징", "count": 3, "color": Color(1.0, 0.75, 0.4)},
	52: {"type": SEAL_CORES, "title": "용의 이빨", "goal": "밭에 뿌려진 용의 이빨 %d개를 뽑아 부수세요", "object": "용의 이빨", "count": 4, "hp": 5.5, "color": Color(0.95, 0.92, 0.8)},
	53: {"type": COLLECT, "title": "황금 양털 조각", "goal": "숲에 흩어진 황금 양털 조각 %d개를 모으세요", "object": "황금 양털", "count": 5, "color": Color(1.0, 0.85, 0.3)},
	54: {"type": ELITE, "title": "아마존 기병대장", "goal": "테미스키라의 기병대장을 쓰러뜨리세요", "elite": "amazon_rider", "color": Color(1.0, 0.7, 0.45)},
	55: {"type": SURVIVE, "title": "거인의 진격", "goal": "거인들의 진격을 %d초 동안 버티세요", "object": "거인의 진격", "time": 35.0, "color": Color(0.9, 0.75, 0.55)},
	56: {"type": ELITE, "title": "칼리돈의 멧돼지", "goal": "사냥터를 휩쓰는 칼리돈의 멧돼지를 잡으세요", "elite": "boar_piglet", "color": Color(0.95, 0.6, 0.4)},
	57: {"type": SEAL_CORES, "title": "해골 제단", "goal": "신전의 해골 제단 %d개를 무너뜨리세요", "object": "해골 제단", "count": 3, "color": Color(0.9, 0.88, 0.75)},
	58: {"type": SEAL_CORES, "title": "불의 균열", "goal": "들판을 가르는 불의 균열 %d곳을 막으세요", "object": "불의 균열", "count": 3, "color": Color(1.0, 0.45, 0.2)},
	59: {"type": ELITE, "title": "늑대 우두머리", "goal": "숲의 늑대 우두머리를 쓰러뜨리세요", "elite": "war_wolf", "color": Color(0.8, 0.75, 0.65)},
	60: {"type": SURVIVE, "title": "군단의 공세", "goal": "군신의 군단을 %d초 동안 막아 내세요", "object": "군단의 공세", "time": 40.0, "color": Color(1.0, 0.4, 0.35)},
	61: {"type": SEAL_CORES, "title": "활터의 과녁", "goal": "활터의 과녁 %d개를 꿰뚫으세요", "object": "과녁", "count": 4, "hp": 4.5, "color": Color(1.0, 0.85, 0.5)},
	62: {"type": ALTAR, "title": "갈라진 땅 봉인", "goal": "봉인진 안에서 %d초 버텨 갈라진 땅을 닫으세요", "object": "갈라진 땅 봉인", "time": 18.0, "color": Color(0.6, 0.95, 0.5)},
	63: {"type": COLLECT, "title": "흩어진 불씨", "goal": "태양 마차가 흘린 불씨 %d개를 모으세요", "object": "불씨", "count": 5, "color": Color(1.0, 0.65, 0.25)},
	64: {"type": COLLECT, "title": "예언의 두루마리", "goal": "불타는 성에 흩어진 예언의 두루마리 %d개를 모으세요", "object": "두루마리", "count": 4, "color": Color(1.0, 0.9, 0.7)},
	65: {"type": SEAL_CORES, "title": "까마귀 둥지", "goal": "숲의 까마귀 둥지 %d개를 털어 내세요", "object": "까마귀 둥지", "count": 4, "hp": 5.0, "color": Color(0.55, 0.5, 0.65)},
	66: {"type": ELITE, "title": "뮈르미돈 대장", "goal": "해변의 뮈르미돈 대장을 쓰러뜨리세요", "elite": "myrmidon", "color": Color(1.0, 0.75, 0.4)},
	67: {"type": COLLECT, "title": "사금", "goal": "강가에서 사금 %d알을 건지세요", "object": "사금", "count": 6, "color": Color(1.0, 0.85, 0.25)},
	68: {"type": SURVIVE, "title": "성벽 공방전", "goal": "트로이 성벽에서 %d초 동안 버티세요", "object": "성벽 공방전", "time": 40.0, "color": Color(1.0, 0.6, 0.4)},
	69: {"type": IGNITE, "title": "신탁의 삼발이", "goal": "신전의 삼발이 %d개에 불을 피우세요", "object": "삼발이", "count": 3, "color": Color(0.9, 0.85, 1.0)},
	70: {"type": IGNITE, "title": "태양의 제단", "goal": "태양의 제단 %d곳을 밝히세요", "object": "태양의 제단", "count": 4, "color": Color(1.0, 0.9, 0.45)},
	71: {"type": SEAL_CORES, "title": "바다뱀의 알", "goal": "해안의 바다뱀 알 %d개를 깨뜨리세요", "object": "바다뱀의 알", "count": 4, "hp": 5.0, "color": Color(0.5, 0.95, 0.75)},
	72: {"type": SEAL_CORES, "title": "성문 빗장", "goal": "트로이 성문의 빗장 %d개를 부수세요", "object": "빗장", "count": 3, "color": Color(0.85, 0.65, 0.45)},
	73: {"type": IGNITE, "title": "봉화", "goal": "안개 속 봉화 %d곳을 올리세요", "object": "봉화", "count": 4, "color": Color(1.0, 0.6, 0.3)},
	74: {"type": ELITE, "title": "어린 키마이라", "goal": "리키아의 하늘을 어지럽히는 어린 키마이라를 잡으세요", "elite": "chimera_cub", "color": Color(1.0, 0.55, 0.35)},
	75: {"type": SURVIVE, "title": "진영 방어", "goal": "그리스 진영을 %d초 동안 지켜 내세요", "object": "진영 방어", "time": 40.0, "color": Color(0.6, 0.8, 1.0)},
	76: {"type": KILL, "title": "구혼자 몰아내기", "goal": "궁전을 차지한 구혼자 무리 %d명을 몰아내세요"},
	77: {"type": SEAL_CORES, "title": "일곱 성문의 깃발", "goal": "테베의 일곱 성문 깃발 %d개를 꺾으세요", "object": "깃발", "count": 7, "hp": 3.0, "color": Color(0.95, 0.5, 0.45)},
	78: {"type": IGNITE, "title": "밤의 횃불", "goal": "올빼미의 밤을 밝힐 횃불 %d개를 켜세요", "object": "횃불", "count": 4, "color": Color(1.0, 0.7, 0.35)},
	79: {"type": ELITE, "title": "청동 중장보병 대장", "goal": "아크로폴리스의 청동 중장보병 대장을 쓰러뜨리세요", "elite": "bronze_hoplite", "color": Color(1.0, 0.75, 0.4)},
	80: {"type": ALTAR, "title": "아테나의 제단", "goal": "아테나의 제단을 %d초 동안 지키세요", "object": "제단 수호", "time": 22.0, "color": Color(0.85, 0.9, 1.0)},
	81: {"type": COLLECT, "title": "금고 열쇠", "goal": "탐욕의 금고 열쇠 %d개를 모으세요", "object": "금고 열쇠", "count": 5, "color": Color(1.0, 0.85, 0.3)},
	82: {"type": IGNITE, "title": "깨우는 종", "goal": "늪의 잠을 깨울 종 %d개를 울리세요", "object": "종", "count": 3, "color": Color(0.85, 0.95, 0.6)},
	83: {"type": SEAL_CORES, "title": "썩은 연회 식탁", "goal": "연회장의 썩은 식탁 %d개를 엎으세요", "object": "연회 식탁", "count": 3, "color": Color(0.7, 0.85, 0.35)},
	84: {"type": SEAL_CORES, "title": "매혹의 향로", "goal": "궁전을 채운 매혹의 향로 %d개를 깨세요", "object": "향로", "count": 3, "color": Color(1.0, 0.5, 0.8)},
	85: {"type": SURVIVE, "title": "묵시록의 행군", "goal": "묵시록의 행군을 %d초 동안 버티세요", "object": "묵시록의 행군", "time": 40.0, "color": Color(0.9, 0.45, 0.4)},
	86: {"type": SEAL_CORES, "title": "짐승의 우상", "goal": "거짓 신전의 짐승 우상 %d개를 부수세요", "object": "짐승의 우상", "count": 3, "color": Color(0.9, 0.3, 0.3)},
	87: {"type": COLLECT, "title": "광야의 만나", "goal": "광야에 내린 만나 %d개를 모으세요", "object": "만나", "count": 6, "color": Color(1.0, 0.98, 0.85)},
	88: {"type": ALTAR, "title": "무저갱의 문 봉인", "goal": "봉인진 안에서 %d초 버텨 무저갱의 문을 닫으세요", "object": "무저갱의 문 봉인", "time": 22.0, "color": Color(0.75, 0.4, 0.9)},
	89: {"type": SEAL_CORES, "title": "재앙의 나팔", "goal": "하늘에 걸린 재앙의 나팔 %d개를 부수세요", "object": "나팔", "count": 7, "hp": 3.0, "color": Color(1.0, 0.8, 0.45)},
	90: {"type": SURVIVE, "title": "메뚜기 떼", "goal": "무저갱의 메뚜기 떼를 %d초 동안 버티세요", "object": "메뚜기 떼", "time": 40.0, "color": Color(0.85, 0.7, 0.35)},
	91: {"type": COLLECT, "title": "생명나무 열매", "goal": "에덴에 떨어진 생명나무 열매 %d개를 모으세요", "object": "열매", "count": 5, "color": Color(0.55, 1.0, 0.55)},
	92: {"type": IGNITE, "title": "눈의 등불", "goal": "바퀴의 하늘에 떠 있는 눈의 등불 %d개를 밝히세요", "object": "눈의 등불", "count": 4, "color": Color(1.0, 0.9, 0.6)},
	93: {"type": SEAL_CORES, "title": "신상의 받침돌", "goal": "금 신상을 떠받친 받침돌 %d개를 부수세요", "object": "받침돌", "count": 3, "color": Color(1.0, 0.85, 0.4)},
	94: {"type": COLLECT, "title": "시냇가의 조약돌", "goal": "시냇가에서 매끄러운 조약돌 %d개를 고르세요", "object": "조약돌", "count": 5, "color": Color(0.8, 0.85, 0.9)},
	95: {"type": IGNITE, "title": "일곱 나팔", "goal": "성벽을 따라 일곱 자리에서 나팔 %d번을 울리세요", "object": "나팔", "count": 7, "color": Color(1.0, 0.85, 0.5)},
	96: {"type": SURVIVE, "title": "홍수", "goal": "물이 빠질 때까지 %d초 버티세요", "object": "홍수", "time": 40.0, "color": Color(0.45, 0.7, 1.0)},
	97: {"type": ALTAR, "title": "엘리야의 제단", "goal": "엘리야의 제단 곁에서 %d초 동안 하늘의 불을 기다리세요", "object": "엘리야의 제단", "time": 22.0, "color": Color(1.0, 0.6, 0.3)},
	98: {"type": COLLECT, "title": "치유의 깃털", "goal": "하늘에서 내려온 치유의 깃털 %d개를 모으세요", "object": "치유의 깃털", "count": 5, "color": Color(0.7, 1.0, 0.85)},
	99: {"type": ELITE, "title": "붉은 용의 새끼", "goal": "하늘의 전쟁터를 휘젓는 붉은 용의 새끼를 잡으세요", "elite": "dragon_whelp", "color": Color(1.0, 0.4, 0.35)},
	100: {"type": IGNITE, "title": "백합", "goal": "정원의 백합 %d송이를 피우세요", "object": "백합", "count": 4, "color": Color(1.0, 1.0, 0.95)},
}


## 이 스테이지의 시련 (기본값을 채워서)
static func get_info(stage: int, tutorial: bool = false) -> Dictionary:
	var info := DEFAULTS.duplicate()
	if stage <= 2 or tutorial or not TABLE.has(stage):
		return info
	info.merge(TABLE[stage], true)
	return info
