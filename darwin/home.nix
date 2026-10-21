{ pkgs, ... }:
{
  imports = [
    ../configs/starship.nix
    ../configs/git.nix
    ../configs/files.nix
    ../configs/tmux.nix
    ../configs/claude.nix
    ../configs/rex.nix
  ];
  options = { };
  config = {
    home.username = "ezekiel";
    home.homeDirectory = "/Users/ezekiel";
    # ~/go/bin: `go install`ed tools (gopls, dlv, ...) used by neovim
    home.sessionPath = [ "$HOME/.local/bin" "$HOME/go/bin" ];
    home.packages = [
      # (Re)install every Go binary neovim needs from upstream @latest.
      # Run after `brew upgrade go` so they're rebuilt against the new Go.
      (pkgs.writeShellScriptBin "go-tools-install" ''
        set -euo pipefail
        command -v go >/dev/null || { echo "go not found; brew install go"; exit 1; }
        tools=(
          golang.org/x/tools/gopls@latest                        # LSP
          golang.org/x/tools/cmd/goimports@latest                # :GoFmt fallback
          github.com/nametake/golangci-lint-langserver@latest    # golangci_lint_ls
          mvdan.cc/gofumpt@latest                                # :GoFmt
          github.com/fatih/gomodifytags@latest                   # :GoAddTag / :GoRmTag
          github.com/cweill/gotests/gotests@latest               # :GoAddTest
          github.com/josharian/impl@latest                       # :GoImpl
          github.com/koron/iferr@latest                          # :GoIfErr
          github.com/go-delve/delve/cmd/dlv@latest               # :GoDebug
          golang.org/x/vuln/cmd/govulncheck@latest               # gopls codelens
        )
        for t in "''${tools[@]}"; do
          echo "==> $t"
          go install "$t"
        done
        echo "installed into $(go env GOPATH)/bin"
      '')
    ];
    xdg.enable = true;
    programs.home-manager.enable = true;
    programs.zsh = {
      enable = true;
      initContent = ''
        bindkey -v
        # re-bind fzf widgets after vi-mode reset (bindkey -v wipes them)
        if typeset -f fzf-history-widget >/dev/null; then
          bindkey '^R' fzf-history-widget
        fi
        if typeset -f fzf-file-widget >/dev/null; then
          bindkey '^T' fzf-file-widget
        fi
        if typeset -f fzf-cd-widget >/dev/null; then
          bindkey '\ec' fzf-cd-widget
        fi
        eval "$(starship init zsh)"
        eval "$(direnv hook zsh)"
        export _ZO_DOCTOR=0
        eval "$(zoxide init zsh)"
        alias cd=z
      '';
    };
    home.stateVersion = "23.11";
  };
}
