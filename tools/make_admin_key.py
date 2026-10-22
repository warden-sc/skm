#!/usr/bin/env python3
"""운영자 키 새로 만들기.

  python3 tools/make_admin_key.py            → 새 키를 무작위로
  python3 tools/make_admin_key.py 내키       → 정한 키로

나온 「해시」를 scripts/autoload/admin.gd 의 ADMIN_KEY_SHA256 에 넣고,
「키」는 저장소에 올리지 말고 본인만 보관 → 환경변수 CRUSADER_ADMIN_KEY 또는 user://admin.key 파일에.
"""
import hashlib
import secrets
import sys

key = sys.argv[1] if len(sys.argv) > 1 else "crusader-dev-" + secrets.token_hex(8)
print("키  :", key)
print("해시:", hashlib.sha256(key.encode("utf-8")).hexdigest())
