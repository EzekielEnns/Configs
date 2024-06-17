# ~/.bashrc: executed by bash(1) for non-login shells.
set -o vi
if command -v fzf-share >/dev/null; then
  source "$(fzf-share)/key-bindings.bash"
  source "$(fzf-share)/completion.bash"
fi
export FZF_COMPLETION_TRIGGER='**'
export FZF_COMPLETION_OPTS='--border --info=inline'
#_fzf_setup_completion git
eval "$(starship init bash)"
export EDITOR=nvim
export VISUAL=nvim
export NIXPKGS_ALLOW_UNFREE=1
