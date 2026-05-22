# cdlg — Console Dialogs for Claude Code

> [!NOTE]
> [Читать на русском](README.ru.md)

A minimal session browser for [Claude Code](https://claude.ai/code). Pick up any past conversation, check token usage, or start a new one — all from a single menu.

## Demo

![cdlg demo](demo.gif)

## Features

- **Project picker** — browse all Claude projects on startup, no `CDLG_DIR` needed
- **Token stats per session** — input, cache-write, cache-read, output at a glance
- **Token totals** — cumulative usage across all sessions in the project
- **Resume by number** — no UUIDs, no digging through `~/.claude/projects/`
- **Bilingual UI** — EN/RU, auto-detected from `$LANG`, toggle with `l`
- **Shell completions** — `--completion bash|zsh` prints a ready-to-source script
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
curl -fsSL https://raw.githubusercontent.com/AliceWork86/cdlg/v0.0.3/cdlg.sh -o /tmp/cdlg.sh
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

## Update

If `cdlg` is already installed, re-run `--install` to overwrite it:

```bash
bash cdlg.sh --install
```

Or update directly from the repository without cloning:

```bash
curl -fsSL https://raw.githubusercontent.com/AliceWork86/cdlg/main/cdlg.sh | bash -s -- --install
```

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

**Session list**

| Key | Action |
|-----|--------|
| `1`–`N` | Resume conversation N |
| `dN` | Delete conversation N |
| Enter | Start a new conversation |
| `l` | Toggle language (EN ↔ RU) |
| `q` | Quit |

**Project picker**

| Key | Action |
|-----|--------|
| `1`–`N` | Open project N |
| `dN` | Delete project N (removes `~/.claude/projects/<slug>`) |
| `l` | Toggle language (EN ↔ RU) |
| `q` | Quit |

## Flags

| Flag | Description |
|------|-------------|
| `--dir <path>` | Sessions directory (overrides `CDLG_DIR`) |
| `--install` | Install to `~/.local/bin` (or `$CDLG_INSTALL_DIR`) |
| `--completion bash\|zsh` | Print shell completion script to stdout |
| `--version` | Print version and exit |
| `--help` | Print help and exit |

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

`CDLG_INSTALL_DIR` overrides the install location (default: `~/.local/bin`):

```bash
CDLG_INSTALL_DIR="$HOME/bin" bash cdlg.sh --install
```

## Session list columns

| Column | Meaning |
|--------|---------|
| `[date]` | Date of last activity in the session |
| `N↕` | Number of messages you sent |
| `model` | Claude model used |
| `↑ input` | Real input tokens billed |
| `+ cache-write` | Tokens written to prompt cache |
| `~ cache-read` | Tokens served from cache (cheaper) |
| `↓ output` | Output tokens generated |

Values ≥ 1000 are shown as `Xk`. All values are cumulative across the entire session.

## License

MIT — see [LICENSE](LICENSE).
