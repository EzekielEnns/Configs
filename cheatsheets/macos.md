so on a fresh install 
- install brew
- install nix
- setup raycast
- import raycast settings
- import zen settings

note that some apps need to be run via command line as they need extra tools/setup i.e yt music
use font book app to look up font names

note that some times you need to boot an app before dealing with it 

note that homebrew is not actually installed by nix

note inorder to do some things i.e setup docker with homebrew you need to
`xcode-select --install` no clue why....


also dokcer demon dose not work without homebrew also kinda weird

some times apps just wont be do-able/have to be removed inorder to todo an update


*if it dose not work---run the *.app file first via spotlight** 


homebrew is installed separately so manage it accordingly


https://chatgpt.com/c/6743b21f-59e8-8001-b414-6b7e0a96be46

for skhd
    `ps aux | grep skhd`
    kill skhd -c /etc/skhdrc
    `launchctl list | grep skhd`
    `launchctl stop org.nixos.skhd`
    `launchctl stop com.koekeishiya.skhd`
    `launchctl start org.nixos.skhd`



setting up homebrew 
- run install script
- if with nix unsitall then reinstall

setting up raycast
- export setings/inport settings
- find actual app setup after homebrew is run
- remove spotlight search
