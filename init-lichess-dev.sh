#!/bin/bash

DEFAULT_LILA_DIR="/home/johnd/lichess/lila"
LILA_WS_DIR="/home/johnd/lichess/lila-ws"
OPENINGEXPLORER_DIR="/home/johnd/lichess/lila-openingexplorer"

START_DIR_FILE="${TMPDIR:-/tmp}/lichess-start-dir"
SESSION_NAME="my_session"
WSL_DISTRO="Ubuntu-24.04"

LILA_DIR="$DEFAULT_LILA_DIR"
if [[ -f "$START_DIR_FILE" ]]; then
  IFS= read -r maybe_dir < "$START_DIR_FILE" || true
  rm -f "$START_DIR_FILE"

  if [[ -n "${maybe_dir:-}" && -d "$maybe_dir" ]]; then
    LILA_DIR="$maybe_dir"
  fi
fi

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  echo "tmux session '$SESSION_NAME' already exists."
  echo "Opening it in a new Windows Terminal window..."
  wt.exe wsl -d "$WSL_DISTRO" -- tmux attach -t "$SESSION_NAME"
  exit 0
fi

tmux new-session -d -s "$SESSION_NAME" "cd '$LILA_DIR' && source ~/.bashrc && echo 'Command: ./lila.sh'; bash"
tmux setw -t "$SESSION_NAME" remain-on-exit on

tmux split-window -h -t "$SESSION_NAME" "cd '$LILA_DIR' && ui/build -w; bash"
tmux split-window -v -t "$SESSION_NAME" "cd '$LILA_DIR' && redis-cli ping || redis-server; bash"
tmux resize-pane -x 10

tmux select-pane -t "$SESSION_NAME:0.0"
tmux split-window -v "cd '$LILA_DIR' && pgrep -x mongod >/dev/null || { sudo rm -f /tmp/mongodb-27017.sock && mongod; }; bash"

tmux split-window -h "cd '$OPENINGEXPLORER_DIR' && source ~/.bashrc && ulimit -n 131072 && EXPLORER_LOG=lila_openingexplorer=info ./target/release/lila-openingexplorer --db-compaction-readahead --lila http://localhost:9663 --cors; bash"
tmux resize-pane -L 30

tmux split-window -h "cd '$LILA_WS_DIR' && source ~/.bashrc && sbt run -Dcsrf.origin=http://localhost:9663; bash"

tmux swap-pane -s 1 -t 2

echo "Started tmux session: $SESSION_NAME"
echo "Opening it in a new Windows Terminal window..."

wt.exe wsl -d "$WSL_DISTRO" -- tmux attach -t "$SESSION_NAME"