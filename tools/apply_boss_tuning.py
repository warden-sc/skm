#!/usr/bin/env python3
"""tools/boss_tuning.tscn 의 출력(「TUNE {json}」 줄)을 보스 씬의 max_hp · defense 에 적용.

    Godot --headless --path . res://tools/boss_tuning.tscn > tune.txt
    python3 tools/apply_boss_tuning.py tune.txt
"""
import json
import os
import re
import sys

REPO = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def set_root_props(path, props):
    text = open(path, encoding="utf-8").read()
    lines = text.split("\n")
    # 첫 [node ...] (부모 없는 루트) 구간
    start = next(i for i, l in enumerate(lines) if l.startswith("[node ") and "parent=" not in l)
    end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("[")), len(lines))
    for key, value in props.items():
        found = False
        for i in range(start + 1, end):
            if re.match(r"^%s = " % key, lines[i]):
                lines[i] = "%s = %s" % (key, value)
                found = True
        if not found:
            # script = … 줄 바로 다음(없으면 헤더 다음)에 넣음
            at = next((i + 1 for i in range(start + 1, end) if lines[i].startswith("script = ")), start + 1)
            lines.insert(at, "%s = %s" % (key, value))
            end += 1
    open(path, "w", encoding="utf-8").write("\n".join(lines))


def main():
    rows = [json.loads(l[5:]) for l in open(sys.argv[1], encoding="utf-8") if l.startswith("TUNE {")]
    for r in rows:
        path = os.path.join(REPO, r["scene"].replace("res://", ""))
        set_root_props(path, {"max_hp": r["hp"], "defense": r["def"]})
    print("applied", len(rows))


if __name__ == "__main__":
    main()
