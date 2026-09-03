#!/usr/bin/env bash
# Shared env for the run_NN_*.sh launchers -- `source` it, never run it.
#
# Sets: ROOT (repo root, cwd), SDV_PY, PY (venv python), PYTHONPATH,
# PYTHONUNBUFFERED/PYTHONIOENCODING, and defines run_stage.
#
# No proxy/transport block, unlike the ncaa-* raw repos this was adapted from:
# statsapi.mlb.com and baseballsavant.mlb.com are both fetched direct, so the
# Decodo residential pool those repos need has no purpose here. That also means
# this file never reads .Renviron -- a capture that needs no credentials should
# not have a code path that goes looking for them.
#
# Usage inside a launcher:
#   source "$(dirname "$0")/_env.sh"
#   run_stage <log-prefix> python/<shim>.py "$@"
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1   # -> baseballr-mlb-raw repo root
ROOT="$(pwd)"

# sdv-py sibling checkout: droplet layout first, then the Windows dev box.
SDV_PY="${SDV_PY:-}"
if [ -z "${SDV_PY}" ]; then
  for c in /mnt/sdv_repos/sdv-py "C:/Users/saiem/Documents/GitHub-Data/sdv-dev/sdv-py"; do
    [ -d "$c" ] && SDV_PY="$c" && break
  done
fi
# Python: this repo's uv venv first, else the sdv-py sibling venv.
# .venv layout is OS-dependent: Linux/droplet = .venv/bin, Windows = .venv/Scripts
for c in "${ROOT}/.venv/bin/python" "${ROOT}/.venv/Scripts/python.exe" \
         "${SDV_PY}/.venv/bin/python" "${SDV_PY}/.venv/Scripts/python.exe"; do
  [ -x "$c" ] && PY="${PY:-$c}" && break
done

# sdv-py checkout FIRST so its feat branches win over the venv-installed pin.
export PYTHONPATH="${SDV_PY}:${ROOT}/python"
export PYTHONUNBUFFERED=1 PYTHONIOENCODING=utf-8

# run_stage <log-prefix> <python-entrypoint> [args...]
# Tees to logs/<prefix>_<ts>.log and propagates the PYTHON exit code -- `$?`
# after a pipe is tee's status, and a bare trailing `echo` would mask a
# hard-stop as success.
run_stage() {
  local prefix="$1" entry="$2"; shift 2
  mkdir -p logs
  local log="logs/${prefix}_$(date +%Y%m%d_%H%M%S).log"
  echo "log -> ${log}  (watch: tail -f ${log})"
  "${PY}" "${entry}" "$@" 2>&1 | tee -a "${log}"
  local rc=${PIPESTATUS[0]}
  echo "EXIT=${rc}" | tee -a "${log}"
  return "${rc}"
}
