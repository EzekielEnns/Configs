
ezekiel in 🌐 nixos in configs on  pixie2 [$!?] is 📦 v1.0.0 via  v24.8.0 2m21s719ms 12:29:29
>> nix build nixpkgs#ipxe -o ./ipxe-bin
ezekiel in 🌐 nixos in configs on  pixie2 [$!?] is 📦 v1.0.0 via  v24.8.0 47ms 12:29:30
>> sudo mkdir -p /srv/tftp
ezekiel in 🌐 nixos in configs on  pixie2 [$!?] is 📦 v1.0.0 via  v24.8.0 16ms 12:29:37
>> sudo install -m 0644 ./ipxe-bin/share/ipxe/undionly.kpxe /srv/tftp/
install: cannot stat './ipxe-bin/share/ipxe/undionly.kpxe': No such file or directory
ezekiel in 🌐 nixos in configs on  pixie2 [$!?] is 📦 v1.0.0 via  v24.8.0 15msx  12:29:41
>> sudo install -m 0644 ./ipxe-bin/undionly.kpxe /srv/tftp/
ezekiel in 🌐 nixos in configs on  pixie2 [$!?] is 📦 v1.0.0 via  v24.8.0 16ms 12:30:10
>> sudo install -m 0644 ./ipxe-bin/ipxe.efi /srv/tftp/
ezekiel in 🌐 nixos in configs on  pixie2 [$!?] is 📦 v1.0.0 via  v24.8.0 16ms 12:30:23
>>

ezekiel in 🌐 nixos in configs on  pixie2 [$!?] is 📦 v1.0.0 via  v24.8.0 5s597ms✦ x  12:30:56
>> sudo cp result/vmlinuz /var/www/ipxe/vmlinuz
sudo cp result/initrd  /var/www/ipxe/initrd
sudo cp result/boot.ipxe /var/www/ipxe/boot.ipxe
>> nix build .#netboot-mini-thin
