#!/usr/bin/env bash
set -euo pipefail

# Export a deterministic frame sequence via the renderer (NOT screenshots)
# Usage:
#   ./scripts/export_sequence.sh "description" [--duration 2.0] [--fps 30]
# Example:
#   ./scripts/export_sequence.sh "shader_demo" --duration 4 --fps 30

DESC="${1:-animation_sequence}"
shift || true
DURATION="2.0"
FPS="30"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --duration)
      DURATION="${2:-2.0}"; shift 2;;
    --fps)
      FPS="${2:-30}"; shift 2;;
    *)
      echo "Unknown arg: $1" >&2; exit 2;;
  esac
done

mkdir -p Resources/communication

cat > Resources/communication/commands.json <<JSON
{
  "action": "export_sequence",
  "description": "${DESC}",
  "duration": ${DURATION},
  "fps": ${FPS},
  "timestamp": $(date +%s)
}
JSON

echo "Queued export_sequence: desc='${DESC}', duration=${DURATION}, fps=${FPS}"
echo "Frames will be written by the renderer into Resources/screenshots/ as they complete."