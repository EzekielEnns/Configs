#!/usr/bin/env bash
# Print a clickable code location for Rex: nvim-link PATH[:LINE[:COL]] [TEXT]
#   --url  print the nvim-open:// URL only (for markdown links)
# Clicking it opens the file in Neovim in this tab (see nvim-open). Outside Rex it prints
# plain PATH:LINE.
set -eu
url_only=
[ "${1:-}" = --url ] && { url_only=1; shift; }
spec=${1:?usage: nvim-link [--url] PATH[:LINE[:COL]] [TEXT]}
text=${2:-$spec}
path=$spec line= col=
if [[ $spec =~ ^(.*):([0-9]+):([0-9]+)$ ]]; then
  path=${BASH_REMATCH[1]} line=${BASH_REMATCH[2]} col=${BASH_REMATCH[3]}
elif [[ $spec =~ ^(.*):([0-9]+)$ ]]; then
  path=${BASH_REMATCH[1]} line=${BASH_REMATCH[2]}
fi
case $path in /*) ;; *) path=$PWD/$path ;; esac
enc() { jq -rn --arg s "$1" '$s | @uri'; }
url="nvim-open://open?file=$(enc "$path")&line=${line:-1}&col=${col:-1}&host=$(hostname -s)"
[ -n "${REX_SESSION:-}" ] && url="$url&session=$(enc "$REX_SESSION")"
[ -n "${REX_BLOCK:-}" ] && url="$url&block=$(enc "$REX_BLOCK")"
if [ -n "$url_only" ]; then
  printf '%s\n' "$url"
elif [ -n "${REX_SESSION:-}" ]; then
  printf '\e]8;;%s\e\\%s\e]8;;\e\\\n' "$url" "$text"
else
  printf '%s\n' "$text"
fi
