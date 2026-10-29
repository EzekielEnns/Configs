#!/usr/bin/env bash
# Open an nvim-open:// link in Neovim, in the Rex tab the link was printed in.
#
#   nvim-open://open?file=/abs/path&line=12&col=3&host=nixos&session=session:…&block=block:…
#
# file is required; the rest is optional. session/block name the Rex pane that printed
# the link (tools add $REX_SESSION/$REX_BLOCK), host the machine the file lives on
# (`hostname -s`). The link is opened:
#   1. in a Neovim already running in that tab: through its server socket (every Neovim
#      makes one), then that pane gets focus;
#   2. else in a new pane to the right of the one that printed the link.
# A file on another host (NVIM_OPEN_HOSTS maps host names to ssh targets) goes to a
# Neovim on that host run from an ssh pane in the tab, else to `ssh -t host nvim` in a
# new pane. Logs to ~/Library/Logs/nvim-open.log.
set -u
exec >>"$HOME/Library/Logs/nvim-open.log" 2>&1
echo "$(date '+%F %T') $1"

url=$1
query=${url#*\?}
[ "$query" = "$url" ] && query=
file= line=1 col=1 host= session= block=
decode() { local s=${1//+/ }; printf '%b' "${s//%/\\x}"; }
IFS='&' read -ra pairs <<<"$query"
for kv in "${pairs[@]}"; do
  k=${kv%%=*} v=$(decode "${kv#*=}")
  case $k in
    file) file=$v ;; line) line=$v ;; col) col=$v ;; host) host=$v ;;
    session) session=$v ;; block) block=$v ;;
  esac
done
[ -n "$file" ] || { echo "no file"; exit 1; }
case $line in '' | *[!0-9]*) line=1 ;; esac
case $col in '' | *[!0-9]*) col=1 ;; esac

# Vim script that opens the file (or switches to its window) and puts the cursor there. Floating
# windows (an open picker, a hover) are closed first, so the file lands in a real window.
vimexpr() {
  local f=${1//\'/\'\'}
  printf "execute('stopinsert').string(luaeval(\"(function() for _, w in ipairs(vim.api.nvim_list_wins()) do if vim.api.nvim_win_get_config(w).relative ~= '' then pcall(vim.api.nvim_win_close, w, true) end end end)()\")).execute('drop '.fnameescape('%s')).execute('call cursor(%d,%d)').execute('normal! zz')" "$f" "$line" "$col"
}

rexs=(rex)
[ -n "$session" ] && rexs+=(-s "$session")

# The tab (Rex window) of the printing pane, and the blocks in it.
window=
if [ -n "$block" ]; then
  window=$("${rexs[@]}" block inspect "$block" --json 2>/dev/null | jq -r '.block.window_id // empty')
  [ -n "$session" ] || session=$("${rexs[@]}" block inspect "$block" --json 2>/dev/null | jq -r '.session_id // empty')
  [ -n "$session" ] && rexs=(rex -s "$session")
fi
blocks=()
if [ -n "$window" ] && [ -n "$session" ]; then
  while IFS= read -r b; do blocks+=("$b"); done < <(rex session inspect "$session" --json |
    jq -r --arg w "$window" '.windows[] | select(.window_id == $w) | .layers[].blocks[].block_id')
fi

fg_of() { "${rexs[@]}" block call -b "$1" process '{}' 2>/dev/null; }

local_host=$(hostname -s)
if [ -z "$host" ] || [ "$host" = "$local_host" ] || [ "$host" = localhost ]; then
  # Neovim 0.12's TUI runs the editor as a child process, which owns the socket.
  sockdir="${TMPDIR:-$(getconf DARWIN_USER_TEMP_DIR)}nvim.$USER"
  for b in "${blocks[@]}"; do
    read -r name pid < <(fg_of "$b" | jq -r '.foreground | "\(.name // "") \(.pid // 0)"')
    [ "$name" = nvim ] || continue
    for p in "$pid" $(pgrep -P "$pid"); do
      for sock in "$sockdir"/*/nvim."$p".0; do
        [ -S "$sock" ] || continue
        if nvim --server "$sock" --remote-expr "$(vimexpr "$file")" >/dev/null; then
          "${rexs[@]}" focus "$b"
          echo "  -> nvim $p in $b"
          exit 0
        fi
      done
    done
  done
  dir=$(dirname "$file")
  [ -d "$dir" ] || dir=$HOME
  anchor=()
  [ -n "$block" ] && anchor=(-b "$block")
  "${rexs[@]}" split "${anchor[@]}" --split=right -c "$dir" -- nvim "+call cursor($line,$col)" "$file"
  echo "  -> new pane"
  exit 0
fi

# Another host: the ssh target for it.
target=$host
for m in ${NVIM_OPEN_HOSTS:-}; do
  [ "${m%%=*}" = "$host" ] && target=${m#*=}
done
q=$(printf '%q' "$file")
# An ssh pane to that host in the tab, with a Neovim running there: send it the file.
for b in "${blocks[@]}"; do
  read -r name pid < <(fg_of "$b" | jq -r '.foreground | "\(.name // "") \(.pid // 0)"')
  [ "$name" = ssh ] || continue
  ps -o args= -p "$pid" | grep -qw -- "$target" || continue
  # The newest Neovim socket of the user there. Rex can't see into the ssh session, so a
  # pane with two remote Neovims gets the one started last.
  sock=$(ssh "$target" 'ls -t /run/user/$(id -u)/nvim.*.0 ${TMPDIR:-/tmp}/nvim.$USER/*/nvim.*.0 2>/dev/null | head -1')
  [ -n "$sock" ] || continue
  if ssh "$target" "nvim --server $sock --remote-expr $(printf '%q' "$(vimexpr "$file")")" >/dev/null; then
    "${rexs[@]}" focus "$b"
    echo "  -> $target nvim $sock in $b"
    exit 0
  fi
done
anchor=()
[ -n "$block" ] && anchor=(-b "$block")
"${rexs[@]}" split "${anchor[@]}" --split=right -- ssh -t "$target" "nvim '+call cursor($line,$col)' $q"
echo "  -> new ssh pane to $target"
