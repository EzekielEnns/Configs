# x forwarding
this bad boy is built into ssh on linux, 
lets you forward gui apps, 
    `ssh -Y endpoint` gets you keyboard and mouse
    `ssh -X endpoint` only gets you mouse

# openvpn
the base openvpn client is a bit dumber then the one you'd get on your phone,
any issues that get thrown at you like a data-cipher or something like that you simply add that value to the
part above the ca i.e.
```
remote .... ...
data-ciphers theCipher
tun-mtu ....
<ca>
```
also note that latency issues normally come from mtu ik on my 3g i needed to set the mtu to 1000
