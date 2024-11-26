{config, pkgs, ...}: 
{
    options = {};
    config = {
    # environment.systemPackages = with pkgs; [
    #     yabai
    # ];
        # services.yabai = {
        #     enable = true;
        #     config = {
        #         auto_balance = "on";
        #         layout = "bsp";
        #     };
        #     extraConfig = ''
        #         yabai -m config mouse_follows_focus on
        #         yabai -m rule --add app='System Preferences' manage=off
        #         # set mouse interaction modifier key (default: fn)
        #         yabai -m config mouse_modifier fn
        #
        #         # set modifier + left-click drag to move window (default: move)
        #         yabai -m config mouse_action1 move
        #
        #         # set modifier + right-click drag to resize window (default: resize)
        #         yabai -m config mouse_action2 resize
        #         '';
        # };
    };
}
