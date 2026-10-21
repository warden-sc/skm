class_name NetInvite
## 초대 코드: 방장 컴퓨터의 주소(IPv4) · 포트 · 방 열쇠를 13글자로 묶은 것 (예: 6R4K-02M8-1ZQ7P)
## 따로 서버가 없어도 되도록 코드 자체에 접속 정보가 들어 있습니다.
##   - 비공개 방은 이 코드(열쇠)를 아는 사람만 들어올 수 있음
##   - 공개 방은 같은 네트워크의 「공개 방 목록」에도 보이고, 코드로도 들어올 수 있음
## 글자는 헷갈리는 I · L · O · U 를 뺀 32글자 (Crockford Base32). 입력할 때 O→0, I/L→1 로 고쳐 읽음.

const ALPHABET := "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
const LENGTH := 13


## ip ("192.168.0.10") · port · key(0~65535) → "XXXX-XXXX-XXXXX" (잘못된 IP 면 "")
static func encode(ip: String, port: int, key: int) -> String:
	var parts := ip.strip_edges().split(".")
	if parts.size() != 4:
		return ""
	var ip_value := 0
	for part in parts:
		if not part.is_valid_int() or int(part) < 0 or int(part) > 255:
			return ""
		ip_value = (ip_value << 8) | int(part)
	var value := (ip_value << 32) | ((port & 0xFFFF) << 16) | (key & 0xFFFF)
	var chars := ""
	for i in LENGTH:
		var shift := 5 * (LENGTH - 1 - i)
		var group := (value >> shift) & 31
		if i == 0:
			group = (value >> shift) & 15  # 맨 앞 글자는 4비트만 (64비트를 13글자에)
		chars += ALPHABET[group]
	return "%s-%s-%s" % [chars.substr(0, 4), chars.substr(4, 4), chars.substr(8)]


## 코드 → {"ip", "port", "key"} (잘못된 코드면 빈 Dictionary)
static func decode(code: String) -> Dictionary:
	var clean := code.strip_edges().to_upper().replace("-", "").replace(" ", "")
	clean = clean.replace("O", "0").replace("I", "1").replace("L", "1")
	if clean.length() != LENGTH:
		return {}
	var value := 0
	for i in LENGTH:
		var index := ALPHABET.find(clean[i])
		if index < 0 or (i == 0 and index > 15):
			return {}
		value = (value << 5) | index
	var ip_value := (value >> 32) & 0xFFFFFFFF
	var port := (value >> 16) & 0xFFFF
	var key := value & 0xFFFF
	if port < 1024 or ip_value == 0:
		return {}
	var ip := "%d.%d.%d.%d" % [(ip_value >> 24) & 255, (ip_value >> 16) & 255, (ip_value >> 8) & 255, ip_value & 255]
	return {"ip": ip, "port": port, "key": key}


## 입력이 초대 코드처럼 생겼는지 (아니면 IP 로 봄)
static func looks_like_code(text: String) -> bool:
	return not text.contains(".") and text.strip_edges().replace("-", "").replace(" ", "").length() == LENGTH
