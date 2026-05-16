{config, pkgs, ...}:
{
    options = {};
    config = {
        programs.git = {
        enable = true;
        signing = {
            # SSH signing — reuses ~/.ssh/github key, no GPG needed.
            # Per-commit opt-in via `git commit -S`. Flip signByDefault to true
            # once both machines have ~/.ssh/github.pub present.
            format = "ssh";
            key = "~/.ssh/github.pub";
            signByDefault = false;
        };
        settings = {
            user = {
                name  = "Zeke";
                email = "ezekiel.enns@protonmail.com";
            };

            alias.capri-sun = "!f() { if [ \"\$1\" = \"-a\" ]; then git commit -am \"\$(git rev-parse --abbrev-ref HEAD) \$2\"; else git commit -m \"\$(git rev-parse --abbrev-ref HEAD) \$1\"; fi; }; f";

            init.defaultBranch = "main";
            mergetool.nvimdiff.cmd = "nvim -d -c \"wincmd l\" -c \"norm ]c\" \"$LOCAL\" \"$MERGED\" \"$REMOTE\"";
            difftool.nvimdiff.cmd = "nvim -d  \"$LOCAL\" \"$REMOTE\"";
            push.default = "current";
            pull.rebase = true;
            rebase.autoStash = true;
            fetch.prune = true;
        };
        };
    };
}
