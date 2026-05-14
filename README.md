# cdlg — Console Dialogs for Claude Code

> [!NOTE]
> [Читать на русском](README.ru.md)

A minimal session browser for [Claude Code](https://claude.ai/code). Pick up any past conversation, check token usage, or start a new one — all from a single menu.

## Demo

```
    ╔═══════════════════════════════════════╗
    ║                                       ║
    ║           ___  ___  _    ___          ║
    ║          / __||   \| |  / __|         ║
    ║         | (__ | |) | |_|\__ \         ║
    ║          \___|___/ |___||___/         ║
    ║                                       ║
    ║         cdlg · Console Dialogs        ║
    ║         script v0.0.1                 ║
    ║                                       ║
    ╚═══════════════════════════════════════╝

  ✓ claude 2.1.139   ✓ python3 3.12.3   ✓ bash 5.2.21

  Dialogs: /home/user/dialogs
  tokens: ↑input  +cache-write  ~cache-read  ↓output  model: cyan

   1. [2026-05-14]  12↕  sonnet-4-6    ↑18k   +64k   ~312k    ↓9k  Explain the authentication flow
   2. [2026-05-13]   7↕  sonnet-4-6     ↑6k   +21k    ~98k    ↓4k  Refactor the parser module
   3. [2026-05-11]   3↕  opus-4-7       ↑2k    +8k    ~14k    ↓1k  Draft release notes for v2.0

  ─────────────────────────────────────────
  Number / Enter — new / l — ru / q — quit:
```

![cdlg demo](demo.gif)

## Features

- **Token stats per session** — input, cache-write, cache-read, output at a glance
- **Resume by number** — no UUIDs, no digging through `~/.claude/projects/`
- **Bilingual UI** — EN/RU, auto-detected from `$LANG`, toggle with `l`
- **Zero dependencies** — bash + python3 stdlib, nothing to install
- **No sudo** — installs to `~/.local/bin` via `--install`
- **bash 3.2+** — works on macOS out of the box

## Concept

Claude Code is already the console chat. `cdlg` is the session layer on top: it reads `~/.claude/projects/` and presents your conversations as a numbered list with token stats. No extra process, no server — just a menu that hands off to `claude`.

The intended setup is a **dedicated dialogs directory**:

```
~/dialogs/          ← your personal Claude conversations live here
```

All sessions launched from this directory are grouped together and shown by `cdlg`.

## Requirements

- [Claude Code](https://claude.ai/code) installed and authenticated (`claude` in PATH)
- `bash` 3.2+
- `python3` (standard, no extra packages)

## Installation

**Quick install (recommended)**

```bash
curl -fsSL https://raw.githubusercontent.com/AliceWork86/cdlg/v0.0.1/cdlg.sh -o /tmp/cdlg.sh
bash /tmp/cdlg.sh --install
```

Installs to `~/.local/bin/cdlg`. No `sudo` required. If `~/.local/bin` is not in your PATH, the script will print what to add to `~/.bashrc` / `~/.zshrc`.

**From source**

```bash
git clone https://github.com/AliceWork86/cdlg.git
bash cdlg/cdlg.sh --install
```

**Run in place**

```bash
git clone https://github.com/AliceWork86/cdlg.git
bash cdlg/cdlg.sh
```

Runs `cdlg` from the current directory — no installation needed.

## First run

`cdlg` shows sessions for the directory you launch it from — the same way Claude Code groups them.

**To see your existing sessions**, run `cdlg` from the directory where you normally use Claude:

```bash
cd ~/your-project
cdlg
```

**To keep all personal conversations in one place**, pick a dedicated directory:

```bash
mkdir -p ~/dialogs
cd ~/dialogs && cdlg
```

From then on, always run `cdlg` from `~/dialogs` — or set `CDLG_DIR` so it works from anywhere:

```bash
export CDLG_DIR="$HOME/dialogs"  # add to ~/.bashrc or ~/.zshrc
cdlg
```

## Usage

| Key | Action |
|-----|--------|
| `1`–`N` | Resume conversation N |
| Enter | Start a new conversation |
| `l` | Toggle language (EN ↔ RU) |
| `q` | Quit |

## Configuration

Edit the two variables at the top of `cdlg.sh`:

```bash
CDLG_DIR=""    # Absolute path to your dialogs directory.
               # Empty = current working directory.
CDLG_LANG=""   # Language: ru, en. Empty = auto-detect from $LANG.
```

Or set them as environment variables without editing the file:

```bash
export CDLG_DIR="$HOME/dialogs"
export CDLG_LANG="en"
```

## Token columns

| Column | Meaning |
|--------|---------|
| `↑ input` | Real input tokens billed |
| `+ cache-write` | Tokens written to prompt cache |
| `~ cache-read` | Tokens served from cache (cheaper) |
| `↓ output` | Output tokens generated |

Values ≥ 1000 are shown as `Xk`. All values are cumulative across the entire session.

## License

MIT — see [LICENSE](LICENSE).
