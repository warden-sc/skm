#!/bin/bash
# 효과음 만들기 — Kenney 효과음 팩(CC0) 4개에서 고른 소리 → 게임용 OGG (assets/audio/sfx/<이름>.ogg)
#   필요한 팩 (kenney.nl, 압축을 풀어 한 폴더에): RPG Audio · Impact Sounds · Sci-fi Sounds · Digital Audio
#   - 몇 개는 소리 2~3개를 겹치고 음을 낮춰 묵직하게 (방패 막기 · 플레이어 피격 · 보스 타격)
#   - 순간이동 · 몬스터 처치는 합성음을 섞음
#   - 모든 소리는 최대 크기를 -1dB 로 맞춤 (상황별 크기는 Sfx.VOLUMES 에서)
#   - 이름 뒤 _2 · _3 … 은 같은 상황의 다른 소리 (Sfx 가 무작위로 골라 반복감을 줄임)
# 사용: bash tools/build_sfx.sh <Kenney 팩들을 푼 폴더>      (ffmpeg 필요)
set -e
SRC=${1:?Kenney 팩 폴더}
OUT=$(dirname "$0")/../assets/audio/sfx
mkdir -p "$OUT"

src() { # 파일 이름으로 찾기
  local f
  f=$(find -L "$SRC" -name "$1.ogg" | head -1)
  [ -n "$f" ] || { echo "없음: $1" >&2; exit 1; }
  echo "$f"
}

# 출력 이름, ffmpeg 입력/필터 인자… → 크기 맞춰 OGG
make() {
  local name=$1; shift
  local tmp
  tmp=$(mktemp --suffix=.wav)
  ffmpeg -nostdin -v error -y "$@" -ac 1 -ar 44100 "$tmp"
  local peak
  peak=$(ffmpeg -nostdin -i "$tmp" -af volumedetect -f null - 2>&1 | sed -n 's/.*max_volume: \(-\?[0-9.]*\) dB/\1/p')
  local gain
  gain=$(awk -v p="$peak" 'BEGIN { printf "%.2f", -1.0 - p }')
  ffmpeg -nostdin -v error -y -i "$tmp" -af "volume=${gain}dB" -c:a libvorbis -q:a 5 "$OUT/$name.ogg"
  rm -f "$tmp"
  echo "$name.ogg"
}

# 하나 그대로
one() { make "$1" -i "$(src "$2")"; }

# 여러 개 겹치고 음 높이(1.0 = 그대로) 바꾸기
layer() {
  local name=$1 pitch=$2; shift 2
  local args=() n=0
  for f in "$@"; do args+=(-i "$(src "$f")"); n=$((n + 1)); done
  make "$name" "${args[@]}" -filter_complex "amix=inputs=$n:normalize=0,asetrate=44100*$pitch,aresample=44100,alimiter=limit=0.95"
}

# ── 화면 · 아이템 (RPG Audio)
one gold_pickup handleCoins2
one shop_buy handleCoins
one equip_weapon drawKnife1
one equip_weapon_2 drawKnife2
one equip_weapon_3 drawKnife3
one equip_armor clothBelt
one equip_armor_2 beltHandle1
one item_pickup handleSmallLeather
one item_drop dropLeather
one inventory_open cloth2
one inventory_close cloth4
one dialogue_next bookFlip2
one dialogue_next_2 bookFlip3
one menu_open bookOpen
one menu_close bookClose
one ui_click metalClick
one denied metalLatch
one footstep footstep00
one footstep_2 footstep03
one footstep_3 footstep06

# ── 월드
one chest_open impactPlank_medium_000
# 보스방 문: 낮게 끄는 문소리 + 땅울림 + 마지막에 「쿵」
make gate_open -i "$(src doorOpen_2)" -i "$(src spaceEngineLow_000)" -i "$(src impactMining_002)" -filter_complex \
  "[0]asetrate=44100*0.55,aresample=44100[a];[1]lowpass=f=300,volume=1.6,atrim=0:2.2,afade=t=in:d=0.3,afade=t=out:st=1.4:d=0.8[r];[2]asetrate=44100*0.6,aresample=44100,adelay=1500|1500[t];[a][r][t]amix=inputs=3:normalize=0,alimiter=limit=0.95"
# 순간이동: 올라가는 소리 + 「쉭」 (합성)
make teleport -f lavfi -i "aevalsrc='0.35*sin(2*PI*(300*t+900*t*t))*exp(-1.5*t)':d=0.7:s=44100" -f lavfi -i "anoisesrc=d=0.7:c=pink:a=0.5:seed=7" -filter_complex \
  "[1]bandpass=f=2500:w=2000,afade=t=in:d=0.25,afade=t=out:st=0.35:d=0.35[n];[0]afade=t=out:st=0.4:d=0.3[s];[s][n]amix=inputs=2:normalize=0,aecho=0.6:0.5:60|120:0.35|0.2,alimiter=limit=0.9"

# ── 전투 (Impact Sounds)
for i in 0 1 2 3 4; do
  one "hit$([ $i -gt 0 ] && echo _$((i + 1)))" "impactPunch_medium_00$i"
done
one hit_crit impactPunch_heavy_003
one hit_crit_2 impactPunch_heavy_004
# 보스 타격: 바위 소리 + 철판, 낮게
layer boss_hit 0.8 impactMining_002 impactPlate_heavy_000
layer boss_hit_2 0.8 impactMining_000 impactPlate_heavy_001
layer boss_hit_3 0.8 impactMining_001 impactPlate_heavy_002
# 방패 막기: 금속 + 묵직한 타격, 낮게
layer guard_block 0.8 impactMetal_heavy_000 impactPunch_heavy_000
one guard_perfect impactBell_heavy_004
one guard_break impactPlate_heavy_000
# 플레이어 피격: 갑옷에 맞는 소리
layer player_hurt 0.85 impactPunch_heavy_004 impactPlate_light_000
layer player_hurt_2 0.85 impactPunch_heavy_002 impactPlate_light_001
# 몬스터 처치: 둔탁한 소리 + 연기처럼 「푸슉」 (합성 잡음)
for i in 0 1 2; do
  make "enemy_death$([ $i -gt 0 ] && echo _$((i + 1)))" -f lavfi -i "anoisesrc=d=0.45:c=brown:a=0.9:seed=$((i + 3))" -i "$(src impactSoft_heavy_00$((i + 2 > 4 ? 4 : i + 2)))" -filter_complex \
    "[0]lowpass=f=1800,afade=t=in:d=0.02,afade=t=out:st=0.05:d=0.4[n];[1]asetrate=44100*0.8,aresample=44100[b];[b][n]amix=inputs=2:normalize=0,alimiter=limit=0.95"
done
one boss_death lowFrequency_explosion_000
make skill_cast -i "$(src laserLarge_000)" -af "asetrate=44100*0.8,aresample=44100"
