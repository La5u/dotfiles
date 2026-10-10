# Opt in in each existing shell: source ~/.config/agent-windows/shell.bash
# Only ordinary, argument-free interactive launches are automatically tracked.
codex() {
    if (( $# == 0 )); then
        "$HOME/.local/bin/agent-window" here codex
    else
        command codex "$@"
    fi
}
claude() {
    if (( $# == 0 )); then
        "$HOME/.local/bin/agent-window" here claude
    else
        command claude "$@"
    fi
}
cw() { "$HOME/.local/bin/agent-window" codex "${1:-$PWD}"; }
clw() { "$HOME/.local/bin/agent-window" claude "${1:-$PWD}"; }
agent-restore() { "$HOME/.local/bin/agent-window" restore "$@"; }
