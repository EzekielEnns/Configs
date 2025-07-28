{ config, pkgs, ... }: 
let
  zellijAutolock = pkgs.fetchurl {
    url = "https://github.com/fresh2dev/zellij-autolock/releases/download/0.2.2/zellij-autolock.wasm";
    sha256 = "194fgd421w2j77jbpnq994y2ma03qzdlz932cxfhfznrpw3mdjb9";
  };
in
{
  config = {

#TODO move cause this is a bad spot for it
   programs.zoxide = {
       enable = true;
       enableZshIntegration = true;
   };
    home.file.".ideavimrc" = {
      source = ./../misc/.ideavimrc;
      recursive = true;
      force = true;
    };

    home.file.".zshrc" = {
      force = true;
      text = "";
    };

    home.file.".config/ghostty/config" = {
      force = true;
      text = ''
        background-opacity = 0.85
        keybind = alt+left=unbind
        keybind = alt+right=unbind
        macos-option-as-alt = true
        macos-titlebar-proxy-icon = hidden
        macos-non-native-fullscreen = true
        # you must hold ⌥ (alt)
        macos-titlebar-style = hidden
        window-decoration = false
        keybind = ctrl+a>n=new_window
        keybind = ctrl+a>h=toggle_window_decorations
        font-size = 15
        font-family = "Monofur Nerd Font Mono"
        theme = gruvbox-material
        quit-after-last-window-closed = true
        cursor-style = block
        cursor-style-blink = false
        shell-integration-features = no-cursor
        mouse-hide-while-typing = true
        window-subtitle = false
        title = " "
        clipboard-write = allow
        copy-on-select = true
      '';
    };

    home.file.".config/zellij/config.kdl" = {
        text = ''
            plugins {
                    tab-bar location="zellij:tab-bar"
                    status-bar location="zellij:status-bar"
                    strider location="zellij:strider"
                    compact-bar location="zellij:compact-bar"
                    session-manager location="zellij:session-manager"
                    welcome-screen location="zellij:session-manager" {
                        welcome_screen true
                    }
                filepicker location="zellij:strider" {
                    cwd "${config.home.homeDirectory}/Documents/repos/"
                }
                configuration location="zellij:configuration"
                    plugin-manager location="zellij:plugin-manager"
                    autolock location="https://github.com/fresh2dev/zellij-autolock/releases/latest/download/zellij-autolock.wasm" {
                        triggers "nvim|vim|v|nv"  // Lock when any open these programs open. They are expected to unlock themselves when closed (e.g., using zellij.vim plugin).
                            watch_triggers "fzf|zoxide|atuin|atac"  // Lock when any of these open and monitor until closed.
                            reaction_seconds "0.3"
                    }
            }
        load_plugins {
            autolock
        }

        default_mode "normal"
            default_shell "zsh"
            theme "gruvbox-dark"
            session_serialization false
            show_release_notes false
            show_startup_tips false
            normal {
                // Intercept `Enter`.
                bind "Enter" {
                    WriteChars "\u{000D}";
                    MessagePlugin "autolock" {};
                }
                //...
            }

        keybinds clear-defaults=true {
            // Keybindings specific to 'Normal' mode.
            // Always available bindings
            shared {
                bind "Alt Shift z" {
                    // Enable the autolock plugin.
                    MessagePlugin "autolock" {payload "enable";};
                }
                // Quick pane creation - always available
                bind "Alt n" { NewPane "Right"; SwitchToMode "Normal"; }
                bind "Alt m" { NewPane "Down"; SwitchToMode "Normal"; }

                // Quick actions - always available
                bind "Alt x" { CloseFocus; SwitchToMode "Normal"; }
                //TODO add things like toggle foucs full screen
                //TODO add toggle tab
                bind "Alt f" { ToggleFloatingPanes; }
                bind "Alt e" { TogglePaneEmbedOrFloating; }

                // Tab management - always available
                bind "Alt ." { NewTab; SwitchToMode "Normal"; }
                bind "Alt Shift /" { SwitchToMode "RenameTab"; TabNameInput 0; }

                bind "Alt s" {
                    LaunchOrFocusPlugin "session-manager" { 
                        floating true
                    };
                    SwitchToMode "normal";
                }

                bind "Alt q" {
                    CloseFocus;
                    SwitchToMode "normal";
                }
            }

            shared_except "locked" {
                bind "Alt z" {
                    // Disable the autolock plugin.
                    MessagePlugin "autolock" {payload "disable";};
                    // Lock Zellij.
                    SwitchToMode "Locked";
                }
                bind "Ctrl m" { SwitchToMode "session"; }
                bind "Ctrl s" { SwitchToMode "Resize"; }
                bind "Ctrl v" { SwitchToMode "Scroll"; }
                bind "Ctrl b" { SwitchToMode "Locked"; }

                bind "Alt l" { GoToNextTab; }
                bind "Alt h" { GoToPreviousTab; }
                bind "Alt j" { GoToNextTab;}
                bind "Alt k" { GoToPreviousTab; }
            }

            shared {
                bind "Alt ;" { FocusNextPane; }
                bind "Alt ," { FocusPreviousPane; }
                bind "Alt h" { GoToPreviousTab; }
                bind "Alt l" { GoToNextTab;}
            }

            locked {
                bind "Ctrl b" { SwitchToMode "Normal"; }
                bind "Alt z" {
                    MessagePlugin "autolock" {payload "disable";};
                    SwitchToMode "Normal";
                }
            }

            resize {
                bind "Alt r" { SwitchToMode "Normal"; }
                bind "h" "Left" { Resize "Left"; }
                bind "j" "Down" { Resize "Down"; }
                bind "k" "Up" { Resize "Up"; }
                bind "l" "Right" { Resize "Right"; }
                bind "=" "+" { Resize "Increase"; }
                bind "-" "_" { Resize "Decrease"; }
                bind "Esc" "Enter" { SwitchToMode "Normal"; }
            }

            scroll {
                bind "Ctrl s" { SwitchToMode "Normal"; }
                bind "e" { EditScrollback; SwitchToMode "Normal"; }
                bind "s" { SwitchToMode "EnterSearch"; SearchInput 0; }
                bind "Ctrl c" { ScrollToBottom; SwitchToMode "Normal"; }
                bind "j" "Down" { ScrollDown; }
                bind "k" "Up" { ScrollUp; }
                bind "Ctrl f" "PageDown" "Right" "l" { PageScrollDown; }
                bind "Ctrl b" "PageUp" "Left" "h" { PageScrollUp; }
                bind "d" { HalfPageScrollDown; }
                bind "u" { HalfPageScrollUp; }
                bind "Esc" "Enter" { SwitchToMode "Normal"; }
            }

            //TODO
            search {
            }

            session {
                bind "Ctrl q" { Quit; }
                bind "Ctrl o" { SwitchToMode "Normal"; }
                bind "d" { Detach; }
                bind "p" {
                    LaunchOrFocusPlugin "plugin-manager" {
                        floating true
                            move_to_focused_tab true
                    };
                    SwitchToMode "Normal"
                }
                bind "Esc" "Enter" { SwitchToMode "Normal"; }
            }

            shared_except "normal" "locked" {
                bind "Enter" "Esc" { SwitchToMode "Normal"; }
            }
        }

        layout_dir "${config.home.homeDirectory}/.config/zellij/layouts"
            '';
        force = true;
    };

    home.file.".config/zellij/layouts/.keep" = {
        text = "keep";
    };
  };
}
