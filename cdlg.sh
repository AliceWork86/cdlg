#!/bin/bash

SCRIPT_VERSION="0.0.5"

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
      echo "cdlg ${SCRIPT_VERSION}"
      exit 0
      ;;
    --help|-h)
      cat <<'EOF'
Usage: cdlg [OPTIONS]

Session browser for Claude Code.

Options:
  --dir <path>          Sessions directory (overrides CDLG_DIR)
  --install             Install to ~/.local/bin (or $CDLG_INSTALL_DIR)
  --completion bash|zsh Print shell completion script to stdout
  --version             Print version and exit
  --help                Print this help and exit

Environment:
  CDLG_DIR          Sessions directory (default: current directory)
  CDLG_LANG         Language: en, ru (default: auto from $LANG)
  CDLG_INSTALL_DIR  Install path (default: ~/.local/bin)

Keys (session list):
  1–N    Resume session N
  dN     Delete session N
  c      Delete all empty sessions (slash-commands only)
  Enter  New session
  l      Toggle EN/RU
  q      Quit

Keys (project picker):
  1–N    Select project N
  dN     Delete project N
  l      Toggle EN/RU
  q      Quit
EOF
      exit 0
      ;;
    --completion)
      case "$2" in
        bash)
          cat <<'EOF'
_cdlg_completion() {
  local cur prev
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  case "$prev" in
    --dir)
      COMPREPLY=( $(compgen -d -- "$cur") )
      return ;;
    --completion)
      COMPREPLY=( $(compgen -W "bash zsh" -- "$cur") )
      return ;;
  esac
  COMPREPLY=( $(compgen -W "--dir --install --completion --version --help" -- "$cur") )
}
complete -F _cdlg_completion cdlg
EOF
          ;;
        zsh)
          cat <<'EOF'
#compdef cdlg
_cdlg() {
  _arguments \
    '--dir[sessions directory]:directory:_directories' \
    '--install[install to ~/.local/bin]' \
    '--completion[print shell completion script]:shell:(bash zsh)' \
    '--version[print version]' \
    '--help[print help]'
}
_cdlg
EOF
          ;;
        *)
          echo "cdlg: --completion requires 'bash' or 'zsh'" >&2
          exit 1
          ;;
      esac
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
LANGS=("en" "ru")           # supported languages, cycled by l key
# ───────────────────────────────────────────

PROJECT_DIR="${CDLG_DIR:-$(pwd)}"
export CDLG_PROJECT_DIR="$PROJECT_DIR"

set_locale() {
  local lang first="" seen=0
  for lang in "${LANGS[@]}"; do
    [[ -z "$first" ]] && first="$lang"
    if [[ $seen -eq 1 ]]; then
      MSG_LANG_SWITCH="$lang"
      seen=2
      break
    fi
    [[ "$lang" == "$_lang" ]] && seen=1
  done
  [[ $seen -eq 1 ]] && MSG_LANG_SWITCH="$first"
  case "$_lang" in
    ru)
      MSG_NO_DIALOGS="Диалогов нет. Начинаем новый."
      MSG_PROMPT="Номер / dN — удал / c — очист / Enter — новый / l — ${MSG_LANG_SWITCH} / q — выход: "
      MSG_CLEAN_CONFIRM="Удалить %n пустых сессий? [y/N]: "
      MSG_CLEAN_NONE="Пустых сессий нет."
      MSG_CLEAN_DONE="Очищено."
      MSG_DIALOGS="Диалоги:"
      MSG_EXIT="Выход."
      MSG_INVALID="Неверный ввод."
      MSG_TOKENS="токены:"
      MSG_INPUT="ввод"
      MSG_CACHE_W="кэш-запись"
      MSG_CACHE_R="кэш-чтение"
      MSG_OUTPUT="вывод"
      MSG_MODEL="модель:"
      MSG_TOTAL="Итого:"
      MSG_PROJECTS="Проекты:"
      MSG_SESSIONS="сессий"
      MSG_SELECT_PROJ="Номер / dN — удал / l — ${MSG_LANG_SWITCH} / q — выход: "
      MSG_DEPS_ERR="Отсутствуют зависимости:"
      MSG_DELETE_FILE="Файл:"
      MSG_DELETE_DIR="Директ.:"
      MSG_DELETE_CONFIRM="Удалить? [y/N]: "
      MSG_DELETE_DONE="Удалено."
      MSG_DELETE_PROJ_CONFIRM="Удалить проект? [y/N]: "
      MSG_DELETE_PROJ_DONE="Проект удалён."
      ;;
    *)
      MSG_NO_DIALOGS="No dialogs. Starting new."
      MSG_PROMPT="Number / dN — del / c — clean / Enter — new / l — ${MSG_LANG_SWITCH} / q — quit: "
      MSG_CLEAN_CONFIRM="Delete %n empty sessions? [y/N]: "
      MSG_CLEAN_NONE="No empty sessions."
      MSG_CLEAN_DONE="Cleaned."
      MSG_DIALOGS="Dialogs:"
      MSG_EXIT="Bye."
      MSG_INVALID="Invalid input."
      MSG_TOKENS="tokens:"
      MSG_INPUT="input"
      MSG_CACHE_W="cache-write"
      MSG_CACHE_R="cache-read"
      MSG_OUTPUT="output"
      MSG_MODEL="model:"
      MSG_TOTAL="Total:"
      MSG_PROJECTS="Projects:"
      MSG_SESSIONS="sessions"
      MSG_SELECT_PROJ="Number / dN — del / l — ${MSG_LANG_SWITCH} / q — quit: "
      MSG_DEPS_ERR="Missing dependencies:"
      MSG_DELETE_FILE="File:"
      MSG_DELETE_DIR="Dir:"
      MSG_DELETE_CONFIRM="Delete? [y/N]: "
      MSG_DELETE_DONE="Deleted."
      MSG_DELETE_PROJ_CONFIRM="Delete project? [y/N]: "
      MSG_DELETE_PROJ_DONE="Project deleted."
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

BANNER_WIDTH=39
BANNER_VER_INDENT=9
VER_STR="script v${SCRIPT_VERSION}"
VER_PAD=$(printf '%*s' $(( BANNER_WIDTH - BANNER_VER_INDENT - ${#VER_STR} )) '')

load_sessions() {
  rows=()
  SESSIONS_DIR_PATH=""
  TOTAL_INP=0; TOTAL_CR=0; TOTAL_RD=0; TOTAL_OUT=0
  while IFS= read -r line; do
    if [[ "$line" == "SESSIONS_DIR|"* ]]; then
      SESSIONS_DIR_PATH="${line#SESSIONS_DIR|}"
    elif [[ "$line" == "TOTALS|"* ]]; then
      IFS='|' read -r _ TOTAL_INP TOTAL_CR TOTAL_RD TOTAL_OUT <<< "$line"
    else
      rows+=("$line")
    fi
  done < <(python3 - <<'PYEOF'
import json, os, re
from pathlib import Path

project_dir = os.environ.get("CDLG_PROJECT_DIR", os.getcwd())
slug = re.sub(r'[^a-zA-Z0-9]', '-', project_dir)
sessions_dir = Path(os.environ.get("HOME", os.path.expanduser("~"))) / f".claude/projects/{slug}"
print(f"SESSIONS_DIR|{sessions_dir}")
def fmt(n): return f"{n//1000}k" if n >= 1000 else str(n)

rows = []
total_inp_real, total_inp_cr, total_inp_rd, total_out = 0, 0, 0, 0

for jsonl_path in sorted(sessions_dir.glob("*.jsonl")) if sessions_dir.is_dir() else []:
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
                    if content and not content.startswith("<") and not content.startswith("/"):
                        if not first_msg:
                            first_msg = content[:60].replace("\r", "").replace("\n", " ")
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

    total_inp_real += inp_real
    total_inp_cr   += inp_cr
    total_inp_rd   += inp_rd
    total_out      += out

    if first_msg:
        last_date = last_ts[:10]
        model_s = re.sub(r'^claude-', '', model)
        model_s = re.sub(r'-\d{8,}.*$', '', model_s) or '?'
        rows.append((last_ts, f"{last_date}|{session_id}|{msg_count}|{model_s}|{'↑'+fmt(inp_real):>7}|{'+'+fmt(inp_cr):>6}|{'~'+fmt(inp_rd):>7}|{'↓'+fmt(out):>6}|{first_msg}"))

print(f"TOTALS|{total_inp_real}|{total_inp_cr}|{total_inp_rd}|{total_out}")
rows.sort(key=lambda x: x[0], reverse=True)
for _, r in rows:
    print(r)
PYEOF
  )
}

project_rows=()

load_projects() {
  project_rows=()
  while IFS= read -r line; do
    project_rows+=("$line")
  done < <(python3 - <<'PYEOF'
import json, os
from pathlib import Path

home = Path(os.environ.get("HOME", os.path.expanduser("~")))
projects_dir = home / ".claude/projects"
results = []

for slug_dir in sorted(projects_dir.iterdir()) if projects_dir.is_dir() else []:
    if not slug_dir.is_dir():
        continue
    cwd = None
    last_ts = ""
    jsonl_files = list(slug_dir.glob("*.jsonl"))
    session_count = len(jsonl_files)
    for jsonl_path in jsonl_files:
        try:
            with open(jsonl_path) as f:
                lines = f.readlines()
            for line in reversed(lines):
                line = line.strip()
                if not line:
                    continue
                try:
                    rec = json.loads(line)
                    ts = rec.get("timestamp", "")
                    if ts:
                        if ts > last_ts:
                            last_ts = ts
                        break
                except Exception:
                    pass
            if cwd is None:
                for line in lines[:20]:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        rec = json.loads(line)
                        if "cwd" in rec:
                            cwd = rec["cwd"]
                            break
                    except Exception:
                        pass
        except Exception:
            pass
    if cwd:
        ts_display = last_ts[:16].replace("T", " ") if last_ts else ""
        results.append(f"{ts_display}\x1f{session_count}\x1f{cwd}\x1f{slug_dir}")

results.sort(key=lambda r: (r.split('\x1f')[0], int(r.split('\x1f')[1])), reverse=True)
for r in results:
    print(r)
PYEOF
  )
}

declare -a ids
declare -a project_paths
declare -a project_slug_dirs

fmt_tok() {
  local n=$1
  if (( n >= 1000000 )); then printf "%dM" $(( n/1000000 ))
  elif (( n >= 1000 )); then printf "%dk" $(( n/1000 ))
  else printf "%d" $n; fi
}

lang_toggle() {
  local lang first="" seen=0
  for lang in "${LANGS[@]}"; do
    [[ -z "$first" ]] && first="$lang"
    if [[ $seen -eq 1 ]]; then
      _lang="$lang"
      seen=2
      break
    fi
    [[ "$lang" == "$_lang" ]] && seen=1
  done
  [[ $seen -eq 1 ]] && _lang="$first"
  set_locale
}

show_banner() {
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
}

show_project_picker() {
  project_paths=()
  project_slug_dirs=()
  clear
  show_banner
  echo ""
  echo -e "  ${W}${MSG_PROJECTS}${N}"
  echo ""

  if [[ ${#project_rows[@]} -eq 0 ]]; then
    echo -e "  ${Y}${MSG_NO_DIALOGS}${N}"
    echo ""
    echo -e "  ${D}─────────────────────────────────────────${N}"
    echo -e -n "  ${Y}${MSG_SELECT_PROJ}${N}"
    return
  fi

  local i=1
  for row in "${project_rows[@]}"; do
    IFS=$'\x1f' read -r date cnt path slug_dir_path <<< "$row"
    project_paths+=("$path")
    project_slug_dirs+=("$slug_dir_path")
    printf "  ${G}%2d.${N} ${D}[%s]${N}  ${W}%2s${N} ${D}%s${N}  %s\n" \
      "$i" "$date" "$cnt" "$MSG_SESSIONS" "$path"
    ((i++))
  done

  echo ""
  echo -e "  ${D}─────────────────────────────────────────${N}"
  echo -e -n "  ${Y}${MSG_SELECT_PROJ}${N}"
}

show_menu() {
  ids=()
  clear
  show_banner
  echo ""

  if [[ ${#rows[@]} -eq 0 ]]; then
    echo -e "  ${Y}${MSG_NO_DIALOGS}${N}"
    echo ""
    echo -e "  ${D}─────────────────────────────────────────${N}"
    echo -e -n "  ${Y}${MSG_PROMPT}${N}"
    return
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
  echo -e "  ${D}${MSG_TOTAL} ${R}↑$(fmt_tok "$TOTAL_INP")${N} ${Y}+$(fmt_tok "$TOTAL_CR")${N} ${D}~$(fmt_tok "$TOTAL_RD")${N} ${G}↓$(fmt_tok "$TOTAL_OUT")${N}"
  echo -e "  ${D}─────────────────────────────────────────${N}"
  echo -e -n "  ${Y}${MSG_PROMPT}${N}"
}

if [[ -z "$CDLG_DIR" ]]; then
  load_projects
  while true; do
    show_project_picker
    read -r choice
    echo ""
    if [[ "$choice" == "l" || "$choice" == "L" ]]; then
      lang_toggle
    elif [[ "$choice" == "q" || "$choice" == "Q" ]]; then
      echo -e "  ${D}${MSG_EXIT}${N}"
      exit 0
    elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#project_paths[@]} )); then
      PROJECT_DIR="${project_paths[$((choice-1))]}"
      export CDLG_PROJECT_DIR="$PROJECT_DIR"
      break
    elif [[ "$choice" =~ ^[dD]([0-9]+)$ ]]; then
      _n="${BASH_REMATCH[1]}"
      if (( _n >= 1 && _n <= ${#project_paths[@]} )); then
        _ppath="${project_paths[$((  _n-1))]}"
        _pslug="${project_slug_dirs[$((_n-1))]}"
        _disp_slug="${_pslug/#$HOME/~}"
        echo -e "  ${W}#${_n}  ${N}${_ppath}"
        echo -e "  ${MSG_DELETE_DIR} ${D}${_disp_slug}${N}"
        _total=0
        while IFS= read -r _f; do
          (( _total++ ))
          if (( _total <= 4 )); then
            echo -e "    ${D}$(basename "$_f")${N}"
          fi
        done < <(ls -1 "${_pslug}"/*.jsonl 2>/dev/null)
        (( _total > 4 )) && echo -e "    ${D}... and $(( _total - 4 )) more${N}"
        echo -e -n "  ${R}${MSG_DELETE_PROJ_CONFIRM}${N}"
        read -r _confirm
        if [[ "$_confirm" == "y" || "$_confirm" == "Y" ]]; then
          if [[ -n "$_pslug" && "$_pslug" == "$HOME/.claude/projects/"* ]]; then
            rm -rf "${_pslug}"
            echo -e "  ${G}${MSG_DELETE_PROJ_DONE}${N}"
          fi
          sleep 1
          load_projects
        fi
      else
        echo -e "  ${R}${MSG_INVALID}${N}"
        sleep 1
      fi
    else
      echo -e "  ${R}${MSG_INVALID}${N}"
      sleep 1
    fi
  done
fi

load_sessions

while true; do
  show_menu
  read -r choice
  echo ""

  if [[ -z "$choice" ]]; then
    cd "$PROJECT_DIR" && exec claude
  elif [[ "$choice" == "l" || "$choice" == "L" ]]; then
    lang_toggle
  elif [[ "$choice" == "q" || "$choice" == "Q" ]]; then
    echo -e "  ${D}${MSG_EXIT}${N}"
    exit 0
  elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#ids[@]} )); then
    cd "$PROJECT_DIR" && exec claude --resume "${ids[$((choice-1))]}"
  elif [[ "$choice" == "c" || "$choice" == "C" ]]; then
    if [[ -n "$SESSIONS_DIR_PATH" && "$SESSIONS_DIR_PATH" == "$HOME/.claude/"* ]]; then
      _empty_ids=()
      _empty_info=()
      while IFS=$'\x1f' read -r _eid _edate _ecmd; do
        [[ -n "$_eid" ]] && _empty_ids+=("$_eid") && _empty_info+=("${_edate} ${_ecmd}")
      done < <(CDLG_CLEAN_DIR="$SESSIONS_DIR_PATH" python3 - <<'CLEANEOF'
import json, os, re as _re
from pathlib import Path
sessions_dir = Path(os.environ.get("CDLG_CLEAN_DIR", ""))
for jsonl_path in sorted(sessions_dir.glob("*.jsonl"), reverse=True) if sessions_dir.is_dir() else []:
    has_msg = False
    last_ts = ""
    cmd_preview = ""
    try:
        with open(jsonl_path) as f:
            for line in f:
                line = line.strip()
                if not line: continue
                rec = json.loads(line)
                ts = rec.get("timestamp", "")
                if ts: last_ts = ts
                is_user = (rec.get("type") == "user" and not rec.get("isMeta")
                           and isinstance(rec.get("message", {}).get("content"), str))
                if is_user:
                    content = rec["message"]["content"].strip()
                    if content and not content.startswith("<") and not content.startswith("/"):
                        has_msg = True
                        break
                    elif not cmd_preview and "<command-message>" in content:
                        m = _re.search(r"<command-message>(.*?)</command-message>", content, _re.DOTALL)
                        if m: cmd_preview = "/" + m.group(1).strip()
                    elif not cmd_preview and "<command-name>" in content:
                        m = _re.search(r"<command-name>(.*?)</command-name>", content, _re.DOTALL)
                        if m: cmd_preview = "/" + m.group(1).strip()
                    elif not cmd_preview and content.startswith("/"):
                        cmd_preview = content.split()[0][:20]
    except Exception:
        pass
    if not has_msg:
        import datetime as _dt
        date = last_ts[:10] if last_ts else _dt.date.fromtimestamp(jsonl_path.stat().st_mtime).isoformat()
        print(f"{jsonl_path.stem}\x1f{date}\x1f{cmd_preview or '(empty)'}")
CLEANEOF
      )
      _cnt=${#_empty_ids[@]}
      if (( _cnt == 0 )); then
        echo -e "  ${D}${MSG_CLEAN_NONE}${N}"
        sleep 1
      else
        for (( _i=0; _i<_cnt; _i++ )); do
          printf "  ${D}%s${N}\n" "${_empty_info[$_i]}"
        done
        echo ""
        echo -e -n "  ${R}${MSG_CLEAN_CONFIRM//%n/$_cnt}${N}"
        read -r _confirm
        if [[ "$_confirm" == "y" || "$_confirm" == "Y" ]]; then
          for _eid in "${_empty_ids[@]}"; do
            rm -f "${SESSIONS_DIR_PATH}/${_eid}.jsonl"
          done
          echo -e "  ${G}${MSG_CLEAN_DONE}${N}"
          sleep 1
          load_sessions
        fi
      fi
    fi
  elif [[ "$choice" =~ ^[dD]([0-9]+)$ ]]; then
    _n="${BASH_REMATCH[1]}"
    if (( _n >= 1 && _n <= ${#ids[@]} )); then
      _sid="${ids[$((_n-1))]}"
      IFS='|' read -r _d _i _c _m _ir _icr _ird _io _preview <<< "${rows[$((_n-1))]}"
      _disp_file="${SESSIONS_DIR_PATH}/${_sid}.jsonl"
      _disp_file="${_disp_file/#$HOME/~}"
      echo -e "  ${D}#${_n}  ${W}${_preview:0:55}${N}"
      echo -e "  ${MSG_DELETE_FILE} ${D}${_disp_file}${N}"
      echo -e -n "  ${R}${MSG_DELETE_CONFIRM}${N}"
      read -r _confirm
      if [[ "$_confirm" == "y" || "$_confirm" == "Y" ]]; then
        if [[ -n "$SESSIONS_DIR_PATH" && "$SESSIONS_DIR_PATH" == "$HOME/.claude/"* ]]; then
          rm -f "${SESSIONS_DIR_PATH}/${_sid}.jsonl"
          echo -e "  ${G}${MSG_DELETE_DONE}${N}"
        fi
        sleep 1
        load_sessions
      fi
    else
      echo -e "  ${R}${MSG_INVALID}${N}"
      sleep 1
    fi
  else
    echo -e "  ${R}${MSG_INVALID}${N}"
    sleep 1
  fi
done
