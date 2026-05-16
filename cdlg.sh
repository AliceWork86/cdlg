#!/bin/bash

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install)
      install_dir="${CDLG_INSTALL_DIR:-$HOME/.local/bin}"
      mkdir -p "$install_dir"
      cp "$0" "$install_dir/cdlg"
      chmod +x "$install_dir/cdlg"
      echo "Installed: $install_dir/cdlg"
      if [[ ":$PATH:" != *":$install_dir:"* ]]; then
        echo ""
        echo "  ~/.local/bin is not in your PATH. Add to ~/.bashrc or ~/.zshrc:"
        echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
      fi
      exit 0
      ;;
    --version|-v)
      echo "cdlg 0.0.1"
      exit 0
      ;;
    --help|-h)
      cat <<'EOF'
Usage: cdlg [OPTIONS]

Session browser for Claude Code.

Options:
  --dir <path>    Sessions directory (overrides CDLG_DIR)
  --install       Install to ~/.local/bin (or $CDLG_INSTALL_DIR)
  --version       Print version and exit
  --help          Print this help and exit

Environment:
  CDLG_DIR          Sessions directory (default: current directory)
  CDLG_LANG         Language: en, ru (default: auto from $LANG)
  CDLG_INSTALL_DIR  Install path (default: ~/.local/bin)

Keys:
  1–N    Resume session N
  Enter  New session
  l      Toggle EN/RU
  q      Quit
EOF
      exit 0
      ;;
    --dir)
      if [[ -z "$2" ]]; then
        echo "cdlg: --dir requires a path" >&2
        exit 1
      fi
      CDLG_DIR="$(cd "$2" 2>/dev/null && pwd || echo "$2")"
      shift
      ;;
    *)
      echo "cdlg: unknown option: $1" >&2
      echo "Try 'cdlg --help' for usage." >&2
      exit 1
      ;;
  esac
  shift
done

# Colors
R='\033[0;31m'
G='\033[0;32m'
B='\033[0;34m'
C='\033[0;36m'
Y='\033[1;33m'
W='\033[1;37m'
D='\033[2;37m'
N='\033[0m'

# ── Settings ───────────────────────────────
CDLG_DIR="${CDLG_DIR:-}"    # path to dialogs directory (empty = current directory)
CDLG_LANG="${CDLG_LANG:-}"  # language: ru, en (empty = auto-detect from $LANG)
# ───────────────────────────────────────────

SCRIPT_VERSION="0.0.1"

PROJECT_DIR="${CDLG_DIR:-$(pwd)}"
export CDLG_PROJECT_DIR="$PROJECT_DIR"

set_locale() {
  case "$_lang" in
    ru)
      MSG_NO_DIALOGS="Диалогов нет. Начинаем новый."
      MSG_PROMPT="Номер / Enter — новый / l — en / q — выход: "
      MSG_DIALOGS="Диалоги:"
      MSG_EXIT="Выход."
      MSG_INVALID="Неверный ввод."
      MSG_TOKENS="токены:"
      MSG_INPUT="ввод"
      MSG_CACHE_W="кэш-запись"
      MSG_CACHE_R="кэш-чтение"
      MSG_OUTPUT="вывод"
      MSG_MODEL="модель:"
      MSG_DEPS_ERR="Отсутствуют зависимости:"
      ;;
    *)
      MSG_NO_DIALOGS="No dialogs. Starting new."
      MSG_PROMPT="Number / Enter — new / l — ru / q — quit: "
      MSG_DIALOGS="Dialogs:"
      MSG_EXIT="Bye."
      MSG_INVALID="Invalid input."
      MSG_TOKENS="tokens:"
      MSG_INPUT="input"
      MSG_CACHE_W="cache-write"
      MSG_CACHE_R="cache-read"
      MSG_OUTPUT="output"
      MSG_MODEL="model:"
      MSG_DEPS_ERR="Missing dependencies:"
      ;;
  esac
}

_lang="${CDLG_LANG:-${LANG%%_*}}"
set_locale

# Filled by check_deps
VER_CLAUDE=""
VER_PYTHON=""
VER_BASH="${BASH_VERSION:-0.0.0}"

check_deps() {
  local ok=1
  local errors=()

  VER_CLAUDE=$(claude --version 2>/dev/null | grep -Eo '[0-9.]+' | head -1)
  if [[ -z "$VER_CLAUDE" ]]; then
    ok=0
    errors+=("  ${R}✗${N} claude    ${R}not found — install from claude.ai/code${N}")
  fi

  VER_PYTHON=$(python3 --version 2>/dev/null | grep -Eo '[0-9.]+' | head -1)
  if [[ -z "$VER_PYTHON" ]]; then
    ok=0
    errors+=("  ${R}✗${N} python3   ${R}not found${N}")
  fi

  if [[ -n "${BASH_VERSION:-}" ]]; then
    if (( BASH_VERSINFO[0] < 3 || (BASH_VERSINFO[0] == 3 && BASH_VERSINFO[1] < 2) )); then
      ok=0
      errors+=("  ${R}✗${N} bash      ${R}${VER_BASH} — requires 3.2+${N}")
    fi
  fi

  if [[ $ok -eq 0 ]]; then
    echo -e "\n  ${R}${MSG_DEPS_ERR}${N}\n"
    for e in "${errors[@]}"; do
      echo -e "$e"
    done
    echo ""
    exit 1
  fi
}

check_deps

VER_STR="script v${SCRIPT_VERSION}"
VER_PAD=$(printf '%*s' $(( 39 - 9 - ${#VER_STR} )) '')

# Load sessions once
rows=()
while IFS= read -r line; do
  rows+=("$line")
done < <(python3 - <<'PYEOF'
import json, os, re
from pathlib import Path

project_dir = os.environ.get("CDLG_PROJECT_DIR", os.getcwd())
slug = re.sub(r'[^a-zA-Z0-9]', '-', project_dir)
sessions_dir = Path(os.environ.get("HOME", os.path.expanduser("~"))) / f".claude/projects/{slug}"
rows = []

for jsonl_path in sorted(sessions_dir.glob("*.jsonl")):
    session_id = jsonl_path.stem
    first_msg, first_ts, last_ts = None, None, ""
    inp_real, inp_cr, inp_rd, out = 0, 0, 0, 0
    msg_count = 0
    model = ""
    seen_usage = set()
    try:
        with open(jsonl_path) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                rec = json.loads(line)
                ts = rec.get("timestamp", "")
                if ts:
                    last_ts = ts
                if rec.get("type") == "assistant":
                    m = rec.get("message", {}).get("model", "")
                    if m:
                        model = m
                is_user = (rec.get("type") == "user" and not rec.get("isMeta")
                           and isinstance(rec.get("message", {}).get("content"), str))
                if is_user:
                    content = rec["message"]["content"].strip()
                    if content and not content.startswith("<"):
                        if not first_msg:
                            first_msg = content[:60].replace("\n", " ")
                            first_ts = ts[:10]
                        msg_count += 1
                msg_id = rec.get("message", {}).get("id")
                u = rec.get("message", {}).get("usage")
                if u and msg_id and msg_id not in seen_usage:
                    seen_usage.add(msg_id)
                    inp_real += u.get("input_tokens", 0)
                    inp_cr   += u.get("cache_creation_input_tokens", 0)
                    inp_rd   += u.get("cache_read_input_tokens", 0)
                    out      += u.get("output_tokens", 0)
    except Exception:
        pass

    if first_msg:
        def fmt(n): return f"{n//1000}k" if n >= 1000 else str(n)
        last_date = last_ts[:10]
        model_s = re.sub(r'^claude-', '', model)
        model_s = re.sub(r'-\d{8,}.*$', '', model_s) or '?'
        rows.append(f"{last_date}|{session_id}|{msg_count}|{model_s}|{'↑'+fmt(inp_real):>7}|{'+'+fmt(inp_cr):>6}|{'~'+fmt(inp_rd):>7}|{'↓'+fmt(out):>6}|{first_msg}")

rows.sort(reverse=True)
for r in rows:
    print(r)
PYEOF
)

declare -a ids

show_menu() {
  ids=()
  clear

  echo -e "${C}"
  echo '    ╔═══════════════════════════════════════╗'
  echo '    ║                                       ║'
  echo '    ║           ___  ___  _    ___          ║'
  echo '    ║          / __||   \| |  / __|         ║'
  echo '    ║         | (__ | |) | |_|\__ \         ║'
  echo '    ║          \___|___/ |___||___/         ║'
  echo '    ║                                       ║'
  echo -e "    ║         ${D}cdlg · Console Dialogs${C}        ║"
  echo -e "    ║         ${D}${VER_STR}${C}${VER_PAD}║"
  echo '    ║                                       ║'
  echo '    ╚═══════════════════════════════════════╝'
  echo -e "${N}"
  echo -e "  ${G}✓${D} claude ${VER_CLAUDE}   ${G}✓${D} python3 ${VER_PYTHON}   ${G}✓${D} bash ${VER_BASH}${N}"
  echo ""

  if [[ ${#rows[@]} -eq 0 ]]; then
    echo -e "  ${Y}${MSG_NO_DIALOGS}${N}"
    cd "$PROJECT_DIR" && exec claude
  fi

  echo -e "  ${W}${MSG_DIALOGS}${N} ${D}${PROJECT_DIR}${N}"
  echo -e "  ${D}${MSG_TOKENS} ${R}↑${D}${MSG_INPUT}  ${Y}+${D}${MSG_CACHE_W}  ~${MSG_CACHE_R}  ${G}↓${D}${MSG_OUTPUT}  ${C}${MSG_MODEL}${D} cyan${N}"
  echo ""

  local i=1
  for row in "${rows[@]}"; do
    IFS='|' read -r date id cnt mdl inp_real inp_cr inp_rd out msg <<< "$row"
    ids+=("$id")
    printf "  ${G}%2d.${N} ${D}[%s]${N} ${W}%3s↕${N} ${C}%-11s${N} ${R}%s${N} ${Y}%s${N} ${D}%s${N} ${G}%s${N}  %s\n" \
      "$i" "$date" "$cnt" "$mdl" "$inp_real" "$inp_cr" "$inp_rd" "$out" "$msg"
    ((i++))
  done

  echo ""
  echo -e "  ${D}─────────────────────────────────────────${N}"
  echo -e -n "  ${Y}${MSG_PROMPT}${N}"
}

while true; do
  show_menu
  read -r choice
  echo ""

  if [[ -z "$choice" ]]; then
    cd "$PROJECT_DIR" && exec claude
  elif [[ "$choice" == "l" || "$choice" == "L" ]]; then
    [[ "$_lang" == "ru" ]] && _lang="en" || _lang="ru"
    set_locale
  elif [[ "$choice" == "q" || "$choice" == "Q" ]]; then
    echo -e "  ${D}${MSG_EXIT}${N}"
    exit 0
  elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#ids[@]} )); then
    cd "$PROJECT_DIR" && exec claude --resume "${ids[$((choice-1))]}"
  else
    echo -e "  ${R}${MSG_INVALID}${N}"
    sleep 1
  fi
done
