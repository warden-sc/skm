#!/bin/bash
# 배경음 원본(Suno → MP3/WAV) → 게임용 OGG (assets/audio/bgm/<이름>.ogg)
#   - 끝의 무음 잘라내기 (Bgm 이 곡 끝과 처음을 겹쳐 이어 붙이므로 무음이 있으면 틈이 생김)
#   - 음량 맞추기 (EBU R128 -16 LUFS, 최대 -1.5 dBTP) — 곡마다 소리 크기가 들쭉날쭉하지 않게
#   - OGG Vorbis 품질 4 (약 128kbps), 44.1kHz 스테레오
# 사용: bash tools/import_bgm.sh <원본 폴더>      (ffmpeg 필요)
set -e
SRC=${1:?원본 폴더}
OUT=$(dirname "$0")/../assets/audio/bgm
mkdir -p "$OUT"
for f in "$SRC"/bgm_*.mp3 "$SRC"/bgm_*.wav; do
  [ -e "$f" ] || continue
  name=$(basename "${f%.*}")
  tmp=$(mktemp --suffix=.wav)
  # 1) 끝의 무음 잘라내기 → 2) 음량 맞추기 + OGG (한 번에 걸면 ffmpeg 가 멈추는 경우가 있어 두 번에 나눔)
  ffmpeg -nostdin -v error -y -i "$f" -af "areverse,silenceremove=start_periods=1:start_threshold=-55dB:start_silence=0.05,areverse" "$tmp"
  ffmpeg -nostdin -v error -y -i "$tmp" -af "loudnorm=I=-16:TP=-1.5:LRA=11" -ar 44100 -ac 2 -c:a libvorbis -q:a 4 "$OUT/$name.ogg"
  rm -f "$tmp"
  echo "$name.ogg"
done
