class_name Hangul
## 영문 자판(두벌식)으로 친 글자를 한글로 조합 — 「gksrmf」 → 「한글」.
## 윈도우 한글 입력기(IME)가 게임 입력 칸에서 한 글자만 들어가는 등 말썽일 때의 대체 수단 (이름 짓기 · 채팅의 [한/영] 버튼).
## 한글 · 숫자 · 기호 등 영문자가 아닌 글자는 그대로 둠.

const CHO := "ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ"
const JUNG := "ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ"
const JONG := ["", "ㄱ", "ㄲ", "ㄳ", "ㄴ", "ㄵ", "ㄶ", "ㄷ", "ㄹ", "ㄺ", "ㄻ", "ㄼ", "ㄽ", "ㄾ", "ㄿ", "ㅀ", "ㅁ", "ㅂ", "ㅄ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"]
## 두벌식 자판
const KEYS := {
	"q": "ㅂ", "w": "ㅈ", "e": "ㄷ", "r": "ㄱ", "t": "ㅅ", "y": "ㅛ", "u": "ㅕ", "i": "ㅑ", "o": "ㅐ", "p": "ㅔ",
	"a": "ㅁ", "s": "ㄴ", "d": "ㅇ", "f": "ㄹ", "g": "ㅎ", "h": "ㅗ", "j": "ㅓ", "k": "ㅏ", "l": "ㅣ",
	"z": "ㅋ", "x": "ㅌ", "c": "ㅊ", "v": "ㅍ", "b": "ㅠ", "n": "ㅜ", "m": "ㅡ",
	"Q": "ㅃ", "W": "ㅉ", "E": "ㄸ", "R": "ㄲ", "T": "ㅆ", "O": "ㅒ", "P": "ㅖ",
}
const VOWEL_PAIRS := {"ㅗㅏ": "ㅘ", "ㅗㅐ": "ㅙ", "ㅗㅣ": "ㅚ", "ㅜㅓ": "ㅝ", "ㅜㅔ": "ㅞ", "ㅜㅣ": "ㅟ", "ㅡㅣ": "ㅢ"}
const FINAL_PAIRS := {"ㄱㅅ": "ㄳ", "ㄴㅈ": "ㄵ", "ㄴㅎ": "ㄶ", "ㄹㄱ": "ㄺ", "ㄹㅁ": "ㄻ", "ㄹㅂ": "ㄼ", "ㄹㅅ": "ㄽ",
	"ㄹㅌ": "ㄾ", "ㄹㅍ": "ㄿ", "ㄹㅎ": "ㅀ", "ㅂㅅ": "ㅄ"}


## 영문자가 하나라도 있는지 (바꿀 게 있는지)
static func has_latin(text: String) -> bool:
	for c in text:
		if KEYS.has(c) or KEYS.has(c.to_lower()):
			return true
	return false


static func from_qwerty(text: String) -> String:
	var out := ""
	var cho := ""
	var jung := ""
	var jong := ""
	for c in text:
		var jamo: String = KEYS.get(c, KEYS.get(c.to_lower(), ""))
		if jamo == "":
			out += _syllable(cho, jung, jong) + c
			cho = ""
			jung = ""
			jong = ""
			continue
		if JUNG.contains(jamo):
			if jong != "":
				# 받침이 다음 글자의 첫소리로 넘어감 (겹받침이면 뒤쪽 하나만)
				var keep := ""
				var move := jong
				for pair in FINAL_PAIRS:
					if FINAL_PAIRS[pair] == jong:
						keep = pair[0]
						move = pair[1]
				out += _syllable(cho, jung, keep)
				cho = move
				jung = jamo
				jong = ""
			elif jung != "":
				if VOWEL_PAIRS.has(jung + jamo):
					jung = VOWEL_PAIRS[jung + jamo]
				else:
					out += _syllable(cho, jung, "")
					cho = ""
					jung = jamo
			else:
				jung = jamo
		else:
			if cho != "" and jung != "" and jong == "" and JONG.has(jamo):
				jong = jamo
			elif jong != "" and FINAL_PAIRS.has(jong + jamo):
				jong = FINAL_PAIRS[jong + jamo]
			else:
				out += _syllable(cho, jung, jong)
				cho = jamo
				jung = ""
				jong = ""
	return out + _syllable(cho, jung, jong)


static func _syllable(cho: String, jung: String, jong: String) -> String:
	if cho != "" and jung != "":
		var code := 0xAC00 + (CHO.find(cho) * 21 + JUNG.find(jung)) * 28 + JONG.find(jong)
		return String.chr(code)
	return cho + jung + jong
