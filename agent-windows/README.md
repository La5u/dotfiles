# Agent session restoration

Installed components:
- `~/.local/bin/agent-window`: private per-window metadata in `~/.local/state/agent-windows`.
- `~/.config/agent-windows/shell.bash`: sourced by interactive Bash.
- Hyprland startup hooks in both installed Lua and legacy configurations call `agent-window restore`.

Activate existing terminals with `source ~/.config/agent-windows/shell.bash`; new Bash terminals activate automatically.
Ordinary argument-free `codex` and `claude` launches are tracked in the current terminal. CLI invocations with arguments are passed through unchanged and are NOT tracked.
`cw [directory]` or `clw [directory]` opens a new tracked Ghostty window (defaults to the current directory).
`agent-restore` reopens saved windows manually.
`agent-window status` lists metadata; `agent-window forget WINDOW_UUID` removes an inactive window.

Only launches after activation are tracked; already-running sessions are not imported.
Successful deliberate CLI exits remove records. Interrupts/crashes retain them. Desktop restart reopens retained conversations by exact UUID, with best-effort original workspace placement. Multiple live copies are prevented by locks.
Codex UUID discovery uses only session metadata in files open by its process tree; when ownership cannot be established, restoration refuses to guess. No credentials or transcript bodies are copied.
Conversation history is resumed, but unsent input, scrollback, exact window layout, live processes and interrupted tools are not restored. Normal application permissions and approvals still apply.

# Pi subscription usage wait

`~/.pi/agent/extensions/usage-resume.ts` loads in new Pi sessions; use `/reload` in an existing session.
On an interactive openai-codex subscription usage error, after built-in retries settle, it waits until the reported reset plus one minute. Without a reset time it waits five hours plus one minute. It then asks Pi to continue the existing unfinished task, at most three times per user task.
Keep Pi running, or reopen the same saved Pi session to restore its pending wait. This does not automatically open Pi windows at desktop login. New input, model changes, or `/usage-resume off` cancel the wait.
Commands: `/usage-resume status`, `/usage-resume off`, `/usage-resume on`, `/usage-resume now`.
Pi's provider sometimes labels a generic HTTP 429 as a ChatGPT usage limit; the extension cannot undo that normalization.

## Repository verification and dependencies

Run `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s agent-windows -p 'test_agent_window*.py' -v` from the repository root. The four config-directory tests and five bin-directory tests are retained in `test_agent_window.py` and `test_agent_window_core.py`, respectively, and target the repository's `bin/agent-window`. Tests use temporary state and mocked launches; no real agents or Ghostty windows are started.

`agent-window` requires Python 3.9+, Linux `/proc` and file locking, Ghostty for new/restored windows, and the relevant `codex` or `claude` CLI. Hyprland's `hyprctl` is optional for workspace tracking/placement. The shell helpers require Bash and the installed `~/.local/bin/agent-window` path. `codex-sub` requires Bash, the Codex CLI, and standard utilities (`mktemp`, `tail`, `cat`, `sed`); `mg.sh` requires Bash, FFmpeg, gifski, and mpv.

The Pi extension described above is not included or tested by this directory. Actual reboot restoration and a real quota reset have not been exercised.
