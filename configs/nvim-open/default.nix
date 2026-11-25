{ config, lib, pkgs, ... }:
# nvim-open:// links: clicking a code location in Rex opens it in Neovim in that tab
# (nvim-open.sh). Tools print the links with `nvim-link`; Claude Code and Pi write them
# as markdown links when they run in Rex.
let
  rexBin = "/Applications/Rex.app/Contents/Helpers/Rex Server.rex/Contents/MacOS";
  # Launch Services starts the handler with a bare PATH. ssh is the system one so it
  # reads ~/.ssh/config like an interactive one; nixos is the desktop's hostname.
  handler = pkgs.writeShellScriptBin "nvim-open" ''
    export PATH="${rexBin}:${lib.makeBinPath [ pkgs.jq ]}:/etc/profiles/per-user/${config.home.username}/bin:/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    export NVIM_OPEN_HOSTS="nixos=desktop"
    exec ${pkgs.bash}/bin/bash ${./nvim-open.sh} "$@"
  '';
  link = pkgs.writeShellScriptBin "nvim-link" ''
    export PATH="${lib.makeBinPath [ pkgs.jq ]}:$PATH"
    exec ${pkgs.bash}/bin/bash ${./nvim-link.sh} "$@"
  '';
  # An AppleScript applet is the smallest thing macOS will hand a URL to (URLs arrive
  # as an Apple Event, not argv). It only forwards the URL to the handler.
  applet = pkgs.writeText "nvim-open.applescript" ''
    on open location u
      do shell script "${handler}/bin/nvim-open " & quoted form of u & " >/dev/null 2>&1 &"
    end open location
  '';
  app = "${config.home.homeDirectory}/Applications/Nvim Open.app";
  lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister";
in
{
  config = {
    home.packages = [ handler link ];

    # osacompile and lsregister are macOS tools outside the Nix build, so the app is
    # made here, and only again when the handler changes.
    home.activation.nvimOpenApp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ "$(cat "${app}/Contents/Resources/nix-source" 2>/dev/null)" != "${applet}" ]; then
        run rm -rf "${app}"
        run mkdir -p "$(dirname "${app}")"
        run /usr/bin/osacompile -o "${app}" ${applet}
        pl="${app}/Contents/Info.plist"
        pb=/usr/libexec/PlistBuddy
        run $pb -c "Set :CFBundleIdentifier com.ezekiel.nvim-open" "$pl" 2>/dev/null \
          || run $pb -c "Add :CFBundleIdentifier string com.ezekiel.nvim-open" "$pl"
        run $pb -c "Add :LSUIElement bool true" \
          -c "Add :CFBundleURLTypes array" -c "Add :CFBundleURLTypes:0 dict" \
          -c "Add :CFBundleURLTypes:0:CFBundleURLName string nvim-open" \
          -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" \
          -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string nvim-open" "$pl"
        # Editing Info.plist breaks osacompile's signature; sign again, ad hoc.
        run /usr/bin/codesign --force --sign - "${app}" 2>/dev/null
        run sh -c 'echo "$1" > "$2"' _ "${applet}" "${app}/Contents/Resources/nix-source"
        run ${lsregister} -f "${app}"
      fi
    '';
  };
}
