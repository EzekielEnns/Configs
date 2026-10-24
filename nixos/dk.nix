{ lib
, config
, inputs
, pkgs
, pkgs-unstable
, ...
}:
{
  # Local AI stack (llama-swap + LiteLLM on the dGPU). Lives in a private repo that's
  # cloned on the desktop, so it's loaded from there (needs --impure, which the rebuild
  # already uses) instead of being a flake input the Mac would also have to fetch.
  imports = [
    (builtins.getFlake "git+file:///home/ezekiel/Documents/repos/ai-stack").nixosModules.default
  ];

  config = {
    services.ai-stack = {
      enable = true;
      listenAddress = "100.64.96.125"; # Tailscale only
      # Cloud models via OpenRouter (prepaid credit). The key is OPENROUTER_API_KEY in
      # /var/lib/ai-stack/secrets.env on the desktop, never in this repo.
      cloudModels =
        let
          # Open-weight models from PRC labs: only established US hosts, never the lab's
          # own API, and no provider that keeps or trains on prompts.
          usHosts = {
            only = [ "deepinfra" "together" "fireworks" "baseten" ];
            allow_fallbacks = false;
            data_collection = "deny";
          };
        in
        {
          cloud-glm = {
            model = "openrouter/z-ai/glm-5.3";
            extra_body.provider = usHosts;
          };
          cloud-deepseek = {
            model = "openrouter/deepseek/deepseek-v4.1-flash";
            extra_body.provider = usHosts;
          };
          cloud-haiku = "openrouter/anthropic/claude-haiku-5.5";
          cloud-sonnet = "openrouter/anthropic/claude-sonnet-5.5";
          cloud-opus = "openrouter/anthropic/claude-opus-5.5";
        };
      planner = "cloud-glm";
    };

    # Claude Code overlay — auto-updating Bun-built binaries direct from
    # Anthropic releases, refreshed hourly. Skips the nixpkgs review lag.
    nixpkgs.overlays = [ inputs.nix-claude-code.overlays.default ];

    # eMudhra intermediates under this root had recoverable private keys
    # (https://harry.id/blog/emudhra-ca-compromise-macos-curl). Browsers block
    # them, but curl/python/git read this bundle. Drop once nixpkgs cacert is patched.
    security.pki.caCertificateBlacklist = [ "emSign ECC Root CA - G3" ];

    environment.systemPackages = [
      pkgs.lm_sensors
      pkgs.glances
      pkgs.htop
      pkgs.nvtopPackages.full
      pkgs.btop
      pkgs.claude-code
      # Native qBittorrent GUI — run on demand instead of the always-on docker
      # container. Point its download dir at /mnt/games/torrents.
      pkgs.qbittorrent
    ];

    users.groups.media = { };
    users.users.ezekiel.extraGroups = [ "media" ];
    # Macbook key (public; safe to commit). Password SSH is off below, so this
    # (or Tailscale SSH) is the way in remotely.
    users.users.ezekiel.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAhiPOtQxrU8YphLKSi9prqAKrpDJcLzRGVdnM03qT8K ezekiel.enns@protonmail.com"
    ];
    #TODO move to harddrive
    systemd.tmpfiles.rules = [
      # top-level media dir + common subdirs (world-writable, setgid)
      "d /srv/media                 2777 root    media - -"
      "Z /srv/media                 2777 root    media - -"

      "d /srv/media/movies          2777 root    media - -"
      "d /srv/media/tv              2777 root    media - -"
      "d /srv/media/anime           2777 root    media - -"
      "d /srv/media/shows           2777 root    media - -"

      # llama models (you asked for all of these to be open too)
      "d /var/lib/llama-cpp/models  2777 root    media - -"

      # torrents landing dir — fully open
      "d /srv/media/torrents        2777 root    media - -"
      "d /srv/music                 2777 root    media - -"

      "d /srv/tftp 0755 root root -"
      "d /var/www/ipxe 0755 root root -"
    ];

    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
        X11Forwarding = true;
      };
    };

    virtualisation.docker.enable = true;
    # nixpkgs marks docker_28 (the default here) insecure and refuses to build it.
    virtualisation.docker.package = pkgs.docker_29;
    virtualisation.docker.enableOnBoot = true;

    virtualisation.docker.daemon.settings = {
      features.cdi = true;
    };
    virtualisation.oci-containers = {
      backend = "docker";
      containers = {
        navidrome = {
          image = "deluan/navidrome:latest";
          ports = [ "4533:4533" ];

          environment = {
            ND_LOGLEVEL = "info";
            ND_BASEURL = "http://music.lan"; # set if you’re behind a reverse proxy
            ND_ENABLETRANSCODINGCONFIG = "false";
          };

          volumes = [
            "/srv/music:/music"
            "/var/lib/navidrome:/data"
          ];
        };

        # qBittorrent is now the native pkgs.qbittorrent GUI (systemPackages),
        # run on demand. Removed from docker on 2026-10-23.
        microbin = {
          ports = [ "127.0.0.1:8084:8080" ];
          image = "danielszabo99/microbin:latest";
          volumes = [ "/var/lib/microbin:/app/microbin_data" ];
        };
        excalidraw = {
          ports = [ "127.0.0.1:8085:80" ];
          image = "excalidraw/excalidraw:latest";
          volumes = [ "/var/lib/excalidraw:/data" ];
        };
        silverBullet = {
          ports = [ "127.0.0.1:8082:3000" ];
          image = "ghcr.io/silverbulletmd/silverbullet:latest";
          volumes = [ "/var/lib/silver:/space" ];
        };
      };
    };

    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      virtualHosts = {
        "qb.lan" = {
          serverName = "qb.lan";
          locations."/" = {
            proxyPass = "http://127.0.0.1:8083";
            proxyWebsockets = true;
          };
        };
        "mb.lan" = {
          serverName = "mb.lan";
          locations."/" = {
            proxyPass = "http://127.0.0.1:8084";
            proxyWebsockets = true;
          };
        };
        "ex.lan" = {
          serverName = "ex.lan";
          locations."/" = {
            proxyPass = "http://127.0.0.1:8085";
            proxyWebsockets = true;
          };
        };
        "sb.lan" = {
          serverName = "sb.lan";
          locations."/" = {
            proxyPass = "http://127.0.0.1:8082";
            proxyWebsockets = true;
          };
        };
        "dc.lan" = {
          serverName = "dc.lan";
          locations."/" = {
            proxyPass = "http://127.0.0.1:6280";
            proxyWebsockets = true;
          };
        };
        "ipxe.lan" = {
          serverName = "ipxe.lan";
          locations."/" = {
            root = "/var/www/ipxe";
            index = "index.html";
          };
        };
        "music.lan" = {
          serverName = "music.lan";
          locations."/" = {
            proxyPass = "http://127.0.0.1:4533";
            proxyWebsockets = true;
          };
        };
      };
    };

    /*
            on mac you need to add the server to dns under settings-> network -> details
              then do sudo mkdir -p /etc/resolver && sudo nvim /etc/resolver/lan
              add nameserver 192.168.1.6
              use this to test
              scutil --dns | grep lan -A3
              dig ai.lan
              curl ai.lan
              remebmer to add the dns to the router, also browsers require http://*.lan they will not auto fill
    */
    systemd.services.dnsmasq.after = [ "dnscrypt-proxy2.service" ];
    systemd.services.dnsmasq.requires = [ "dnscrypt-proxy2.service" ];
    services.dnscrypt-proxy = {
      enable = true;
      settings = {
        listen_addresses = [ "127.0.0.1:5053" ];
        require_dnssec = true;
        # Pick resolvers that support DoH/DoT — Cloudflare, Google, Quad9, etc.
        server_names = [
          "cloudflare"
          "google"
        ];
        # Optional but recommended
        cache = true;
      };
    };
    services.dnsmasq = {
      enable = true;
      resolveLocalQueries = true;

      settings = {
        no-resolv = true;
        strict-order = true;
        domain-needed = true;
        bogus-priv = true;
        enable-tftp = true;
        tftp-root = "/srv/tftp";
        expand-hosts = true;
        listen-address = [
          "127.0.0.1"
          "192.168.1.6"
        ];
        server = [
          "127.0.0.1#5053"
        ];
        local = [ "/lan/" ];
        address = [
          "/qb.lan/192.168.1.6"
          "/sb.lan/192.168.1.6"
          "/music.lan/192.168.1.6"
          "/dc.lan/192.168.1.6"
          "/ex.lan/192.168.1.6"
          "/mb.lan/192.168.1.6"
          "/ipxe.lan/192.168.1.6"
        ];

        # Tag requests by architecture (0 = BIOS, 7/9 = x86_64 UEFI)
        # (This matches iPXE docs; we’ll serve the right binary per arch.) :contentReference[oaicite:1]{index=1}
        "dhcp-match" = [
          "set:bios,option:client-arch,0"
          "set:efi64,option:client-arch,7"
          "set:efi64,option:client-arch,9"
        ];

        # Tag requests that are ALREADY iPXE (DHCP user class 77 = "iPXE") :contentReference[oaicite:2]{index=2}
        "dhcp-userclass" = [ "set:ipxe,iPXE" ];

        # If it's iPXE, give it the HTTP script; otherwise chainload iPXE via TFTP
        "dhcp-boot" = [
          "tag:ipxe,http://ipxe.lan/boot.ipxe"
          "tag:bios,undionly.kpxe"
          "tag:efi64,ipxe.efi"
        ];
      };
    };

    networking.interfaces.enp6s0.wakeOnLan = {
      enable = true;
    };
    networking.networkmanager.enable = true;
    # modules/networking.nix turns the firewall off for every host; this one serves the
    # LAN (dns, pxe, nginx *.lan) and the ports below are what it means to expose.
    # Tailscale is trusted below; Steam adds its own ports; Docker bypasses it anyway.
    networking.firewall.enable = lib.mkForce true;
    networking.firewall.allowedUDPPorts = [
      53
      6881
      67
      69
    ];
    networking.firewall.allowedTCPPorts = [
      #dns
      53
      #ssh
      22
      #http
      80
      443
      #qbit
      6881
      #docs mcp
      6280
    ];

    networking.interfaces.enp6s0.ipv4.addresses = [
      {
        address = "192.168.1.6";
        prefixLength = 24;
      }
    ];

    networking.networkmanager.unmanaged = [ "enp6s0" ];

    services.tailscale = {
      enable = true;
      # stable lags tailscale releases by months; the Mac client comes from brew
      package = pkgs-unstable.tailscale;
      openFirewall = true; # let tailscale traffic in/out
      useRoutingFeatures = "server"; # turns this box into a subnet router
      extraUpFlags = [
        "--advertise-routes=192.168.1.0/24" # <- change if your LAN is different
        "--ssh" # optional, enables Tailscale SSH
      ];
    };

    # Optional but recommended: trust Tailscale interface in your firewall
    networking.firewall.trustedInterfaces = [ "tailscale0" ];
  };
}
