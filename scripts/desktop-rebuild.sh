#!/bin/sh
# Desktop rebuild as its own systemd job, so it survives the Rex server restarting mid-switch.
# Root builds ezekiel's checkout, so git needs safe.directory: nixos/dk.nix sets it for good;
# the throwaway HOME below covers a desktop that doesn't have that setting yet.
R=/home/ezekiel/Documents/repos/configs
U=configs-rebuild-$(date +%s)
cd "$R" || exit 1
echo "== desktop rebuild ($U): touch the sensor on the Mac (or type the desktop password) =="
sudo sh -c "install -d -m 700 /run/$U && printf '[safe]\n\tdirectory = %s\n\tdirectory = %s\n\tdirectory = %s\n' '$R' /home/ezekiel/Documents/repos/ai-stack /home/ezekiel/Documents/repos/evidence > /run/$U/.gitconfig" || exit 1
sudo systemd-run --unit="$U" -p WorkingDirectory="$R" \
  -p Environment=PATH=/run/wrappers/bin:/run/current-system/sw/bin -p Environment=HOME=/run/$U \
  /run/current-system/sw/bin/nixos-rebuild switch --flake .#desktop --impure || exit 1
sudo journalctl -fu "$U" -o cat & J=$!
while s=$(systemctl show -p ActiveState --value "$U"); [ "$s" = activating ] || [ "$s" = active ]; do sleep 3; done
sleep 2; kill $J 2>/dev/null; sudo rm -rf "/run/$U"
RES=$(systemctl show -p Result --value "$U"); echo "== RESULT: $RES =="; [ "$RES" = success ]
