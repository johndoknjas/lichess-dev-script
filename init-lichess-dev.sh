#!/bin/bash
DEFAULT_LILA_DIR="/Users/john.doknjas/lichess/lila"
LILA_WS_DIR="/Users/john.doknjas/lichess/lila-ws"
OPENINGEXPLORER_DIR="/Users/john.doknjas/lichess/lila-openingexplorer"

# If start-lila() was used, it drops the caller's cwd here.
START_DIR_FILE="${TMPDIR:-/tmp}/lichess-start-dir"

LILA_DIR="$DEFAULT_LILA_DIR"
if [[ -f "$START_DIR_FILE" ]]; then
  # Read first line only
  IFS= read -r maybe_dir < "$START_DIR_FILE" || true
  rm -f "$START_DIR_FILE"

  if [[ -n "${maybe_dir:-}" && -d "$maybe_dir" ]]; then
    LILA_DIR="$maybe_dir"
  fi
fi

tmux new-session -d -s my_session "cd '$LILA_DIR' && source ~/.zshrc && echo 'Command: ./lila.sh'; bash"
tmux setw remain-on-exit on
tmux split-window -h "cd '$LILA_DIR' && ui/build -w; bash"
tmux split-window -v "cd '$LILA_DIR' && killall redis-server && sleep 1; redis-server; bash"
tmux select-pane -t 0
tmux split-window -v "cd '$LILA_DIR' && mongod; bash"
tmux split-window -h "cd '$OPENINGEXPLORER_DIR' && source ~/.zshrc && ulimit -n 131072 && EXPLORER_LOG=lila_openingexplorer=info ./target/release/lila-openingexplorer --db-compaction-readahead --lila http://localhost:9663 --cors; bash"
tmux split-window -h "cd '$LILA_WS_DIR' && source ~/.zshrc && sbt run -Dcsrf.origin=http://localhost:9663; bash"
tmux swap-pane -s 1 -t 2
tmux -2 attach-session -d