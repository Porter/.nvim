#!/usr/bin/env bash
# Notification helper script for Neovim terminal buffers running inside Tmux.
# Accepts a description string as its argument.
# Usage: ./notify.sh "Task completed"

SOCKET_PATH="${NOTIFICATION_SOCKET:-/tmp/notification_daemon.sock}"
DESCRIPTION="$1"

# 1. Get nvim_buf_id from $NVIM_BUF_ID
NVIM_BUF_ID="${NVIM_BUF_ID}"
if [ -z "$NVIM_BUF_ID" ] && [ -n "$NVIM" ]; then
  NVIM_BUF_ID=$(nvim --server "$NVIM" --remote-expr "bufnr('%')" 2>/dev/null)
fi

if [ -z "$NVIM_BUF_ID" ]; then
  echo "Error: \$NVIM_BUF_ID is not set (must be run inside a Neovim terminal)." >&2
  exit 1
fi

# 2. Get tmux window number for the current pane (works even if user switched active windows)
if [ -n "$TMUX_PANE" ]; then
  TMUX_WINDOW_ID=$(tmux display-message -p -F '#{window_index}' -t "$TMUX_PANE" 2>/dev/null)
else
  TMUX_WINDOW_ID=$(tmux display-message -p -F '#{window_index}' 2>/dev/null)
fi

if [ -z "$TMUX_WINDOW_ID" ]; then
  echo "Error: Could not retrieve tmux window number." >&2
  exit 1
fi

# 3. Verify daemon socket exists
if [ ! -S "$SOCKET_PATH" ]; then
  echo "Error: Socket $SOCKET_PATH not found. Is the notification daemon running?" >&2
  exit 1
fi

# 4. Format JSON payload safely
PAYLOAD=$(python3 -c "import json, sys; print(json.dumps({'action': 'log', 'tmux_window_id': sys.argv[1], 'nvim_buf_id': sys.argv[2], 'description': sys.argv[3]}))" "$TMUX_WINDOW_ID" "$NVIM_BUF_ID" "$DESCRIPTION")

# 5. Send payload to daemon over Unix socket
echo "sending..."
echo "$PAYLOAD" | nc -N -U "$SOCKET_PATH"
