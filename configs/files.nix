{ config, pkgs, ... }: 
let
  zellijAutolock = pkgs.fetchurl {
    url = "https://github.com/fresh2dev/zellij-autolock/releases/download/0.2.2/zellij-autolock.wasm";
    sha256 = "194fgd421w2j77jbpnq994y2ma03qzdlz932cxfhfznrpw3mdjb9";
  };
in
{
  config = {
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
        keybind = alt+left=unbind
        keybind = alt+right=unbind
        macos-option-as-alt = true
        macos-titlebar-style = "native"
        macos-titlebar-proxy-icon = hidden
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
                bind "Alt |" { NewPane "Down"; SwitchToMode "Normal"; }
                bind "Alt -" { NewPane "Right"; SwitchToMode "Normal"; }
                bind "Alt n" { NewPane "Down"; SwitchToMode "Normal"; }
                bind "Alt m" { NewPane "Right"; SwitchToMode "Normal"; }

                // Quick resize - always available
                bind "Alt =" "Alt +" { Resize "Increase"; }
                bind "Alt _" { Resize "Decrease"; }

                // Quick actions - always available
                bind "Alt x" { CloseFocus; SwitchToMode "Normal"; }
                bind "Alt z" { ToggleFocusFullscreen; SwitchToMode "Normal"; }
                bind "Alt f" { ToggleFloatingPanes; }

                // Tab navigation - always available
                bind "Alt 1" { GoToTab 1; SwitchToMode "Normal"; }
                bind "Alt 2" { GoToTab 2; SwitchToMode "Normal"; }
                bind "Alt 3" { GoToTab 3; SwitchToMode "Normal"; }
                bind "Alt 4" { GoToTab 4; SwitchToMode "Normal"; }
                bind "Alt 5" { GoToTab 5; SwitchToMode "Normal"; }
                bind "Alt 6" { GoToTab 6; SwitchToMode "Normal"; }
                bind "Alt 7" { GoToTab 7; SwitchToMode "Normal"; }
                bind "Alt 8" { GoToTab 8; SwitchToMode "Normal"; }
                bind "Alt 9" { GoToTab 9; SwitchToMode "Normal"; }
                bind "Alt u" { GoToPreviousTab; }
                bind "Alt o" { GoToNextTab; }

                // Tab management - always available
                bind "Alt ." { NewTab; SwitchToMode "Normal"; }
                bind "Alt _" { SwitchToMode "RenameTab"; TabNameInput 0; }

                // Session management - always available
                bind "Alt s" {
                    LaunchOrFocusPlugin "session-manager" {
                        floating true
                            move_to_focused_tab true
                    };
                    SwitchToMode "Normal"
                }
            }

            shared_except "locked" {
                bind "Alt z" {
                    // Disable the autolock plugin.
                    MessagePlugin "autolock" {payload "disable";};
                    // Lock Zellij.
                    SwitchToMode "Locked";
                }
                bind "Ctrl a" { SwitchToMode "Pane"; }
                bind "Ctrl o" { SwitchToMode "Session"; }
                bind "Alt r" { SwitchToMode "Resize"; }
                bind "Ctrl s" { SwitchToMode "Scroll"; }
                bind "Ctrl t" { SwitchToMode "Tab"; }
                bind "Ctrl m" { SwitchToMode "Move"; }
                bind "Ctrl q" { Quit; }
                bind "Ctrl b" { SwitchToMode "Locked"; }

                bind "Alt h" {
                    MoveFocusOrTab "Left";
                }
                bind "Alt l" {
                    MoveFocusOrTab "Right";
                }
                bind "Alt j" {
                    MoveFocus "Down";
                }
                bind "Alt k" {
                    MoveFocus "Up";
                }
            }

            locked {
                bind "Ctrl b" { SwitchToMode "Normal"; }
                bind "Alt z" {
                    MessagePlugin "autolock" {payload "disable";};
                    SwitchToMode "Normal";
                }
            }

            pane {
                bind "Ctrl a" { SwitchToMode "Normal"; }
                bind "h" "Left" { MoveFocus "Left"; }
                bind "l" "Right" { MoveFocus "Right"; }
                bind "j" "Down" { MoveFocus "Down"; }
                bind "k" "Up" { MoveFocus "Up"; }
                bind "p" { SwitchFocus; }
                bind "c" { NewPane; SwitchToMode "Normal"; }
                bind "\"" { NewPane "Down"; SwitchToMode "Normal"; }
                bind "%" { NewPane "Right"; SwitchToMode "Normal"; }
                bind "x" { CloseFocus; SwitchToMode "Normal"; }
                bind "f" { ToggleFocusFullscreen; SwitchToMode "Normal"; }
                bind "z" { TogglePaneFrames; SwitchToMode "Normal"; }
                bind "w" { ToggleFloatingPanes; SwitchToMode "Normal"; }
                bind "e" { TogglePaneEmbedOrFloating; SwitchToMode "Normal"; }
                bind "r" { SwitchToMode "RenamePane"; PaneNameInput 0; }
                bind "i" { TogglePanePinned; SwitchToMode "Normal"; }
                bind "Esc" "Enter" { SwitchToMode "Normal"; }
            }

            resize {
                bind "Alt r" { SwitchToMode "Normal"; }
                bind "h" "Left" { Resize "Left"; }
                bind "j" "Down" { Resize "Down"; }
                bind "k" "Up" { Resize "Up"; }
                bind "l" "Right" { Resize "Right"; }
                bind "=" "+" { Resize "Increase"; }
                bind "-" { Resize "Decrease"; }
                bind "Esc" "Enter" { SwitchToMode "Normal"; }
            }

            tab {
                bind "Ctrl t" { SwitchToMode "Normal"; }
                bind "r" { SwitchToMode "RenameTab"; TabNameInput 0; }
                bind "h" "Left" "Up" "k" { GoToPreviousTab; }
                bind "l" "Right" "Down" "j" { GoToNextTab; }
                bind "n" { NewTab; SwitchToMode "Normal"; }
                bind "x" { CloseTab; SwitchToMode "Normal"; }
                bind "s" { ToggleActiveSyncTab; SwitchToMode "Normal"; }
                bind "b" { BreakPane; SwitchToMode "Normal"; }
                bind "]" { BreakPaneRight; SwitchToMode "Normal"; }
                bind "[" { BreakPaneLeft; SwitchToMode "Normal"; }
                bind "1" { GoToTab 1; SwitchToMode "Normal"; }
                bind "2" { GoToTab 2; SwitchToMode "Normal"; }
                bind "3" { GoToTab 3; SwitchToMode "Normal"; }
                bind "4" { GoToTab 4; SwitchToMode "Normal"; }
                bind "5" { GoToTab 5; SwitchToMode "Normal"; }
                bind "6" { GoToTab 6; SwitchToMode "Normal"; }
                bind "7" { GoToTab 7; SwitchToMode "Normal"; }
                bind "8" { GoToTab 8; SwitchToMode "Normal"; }
                bind "9" { GoToTab 9; SwitchToMode "Normal"; }
                bind "Tab" { ToggleTab; }
                bind "Esc" "Enter" { SwitchToMode "Normal"; }
            }

            move {
                bind "Ctrl m" { SwitchToMode "Normal"; }
                bind "n" "Tab" { MovePane; }
                bind "p" { MovePaneBackwards; }
                bind "h" "Left" { MovePane "Left"; }
                bind "j" "Down" { MovePane "Down"; }
                bind "k" "Up" { MovePane "Up"; }
                bind "l" "Right" { MovePane "Right"; }
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

            search {
                bind "Ctrl s" { SwitchToMode "Normal"; }
                bind "Ctrl c" { ScrollToBottom; SwitchToMode "Normal"; }
                bind "j" "Down" { ScrollDown; }
                bind "k" "Up" { ScrollUp; }
                bind "Ctrl f" "PageDown" "Right" "l" { PageScrollDown; }
                bind "Ctrl b" "PageUp" "Left" "h" { PageScrollUp; }
                bind "d" { HalfPageScrollDown; }
                bind "u" { HalfPageScrollUp; }
                bind "n" { Search "down"; }
                bind "p" { Search "up"; }
                bind "c" { SearchToggleOption "CaseSensitivity"; }
                bind "w" { SearchToggleOption "Wrap"; }
                bind "o" { SearchToggleOption "WholeWord"; }
                bind "Esc" "Enter" { SwitchToMode "Normal"; }
            }

            entersearch {
                bind "Ctrl c" "Esc" { SwitchToMode "Scroll"; }
                bind "Enter" { SwitchToMode "Search"; }
            }

            renametab {
                bind "Ctrl c" { SwitchToMode "Normal"; }
                bind "Esc" { UndoRenameTab; SwitchToMode "Tab"; }
            }

            renamepane {
                bind "Ctrl c" { SwitchToMode "Normal"; }
                bind "Esc" { UndoRenamePane; SwitchToMode "Pane"; }
            }

            session {
                bind "Ctrl o" { SwitchToMode "Normal"; }
                bind "w" {
                    LaunchOrFocusPlugin "session-manager" {
                        floating true
                            move_to_focused_tab true
                    };
                    SwitchToMode "Normal"
                }
                bind "Ctrl s" { SwitchToMode "Scroll"; }
                bind "d" { Detach; }
                bind "c" {
                    LaunchOrFocusPlugin "configuration" {
                        floating true
                            move_to_focused_tab true
                    };
                    SwitchToMode "Normal"
                }
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
