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
    ../modules/notes-sync.nix # the shared notes vault: Syncthing over Tailscale, hourly snapshots
  ];

  config = {
    services.ai-stack = {
      enable = true;
      listenAddress = "100.64.96.125"; # Tailscale only
      # Brave search through the gateway (legacy Free AI plan). The key is BRAVE_API_KEY in
      # /var/lib/ai-stack/secrets.env, never in this repo.
      braveSearch = true;
      # Web evidence service (ai-stack docs/RAG-PLAN.md), from its own private repo cloned
      # next to ai-stack: /evidence (search, fetch, rank, prune) and /prune, on :8090. Pi's
      # lookup and fetch_content use it (configs/pi-extensions/web).
      evidence = {
        enable = true;
        package = (builtins.getFlake "git+file:///home/ezekiel/Documents/repos/evidence").packages.x86_64-linux.evidence;
        # Open Provence (ONNX export, ~600 MB) copied into the store by hash, since the
        # service can't read home folders. Re-export: evidence/tools/export_provence.py.
        provence = {
          model = builtins.path {
            path = /home/ezekiel/ai-helpers/models/provence.onnx;
            name = "provence.onnx";
            sha256 = "sha256-CnqTmCEV7A5yIclsDZMo9b+TzZ0EcbejUx4vTBH0Ook=";
          };
          tokenizer = builtins.path {
            path = /home/ezekiel/ai-helpers/models/open-provence-en-gte-911517e2/tokenizer.json;
            name = "provence-tokenizer.json";
            sha256 = "sha256-ZXjEtileMfdiuamtRcRRZPM7Nvxw+xWKn4VkXa+2/CQ=";
          };
        };
      };
      # Cloud models via OpenRouter (prepaid credit). The key is OPENROUTER_API_KEY in
      # /var/lib/ai-stack/secrets.env on the desktop, never in this repo.
      cloudModels =
        let
          # Zero data retention: only hosts that store no prompts or outputs at all, not even
          # for abuse review (OpenRouter's ZDR list). Red-team work goes through here, so a
          # request with no ZDR host fails instead of landing on one that keeps it.
          zdr = { zdr = true; data_collection = "deny"; };
          # Open-weight models from PRC labs: only established US hosts, never the lab's
          # own API. All four are on the ZDR list for these models (checked 2026-10-29).
          usHosts = zdr // {
            only = [ "deepinfra" "together" "fireworks" "baseten" ];
            allow_fallbacks = false;
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
          # Worker candidate (open weights, OpenAI): cheap reading for pi-orch workers.
          cloud-gptoss = {
            model = "openrouter/openai/gpt-oss-120b";
            extra_body.provider = usHosts;
          };
          # teardown's pick bake-off (VY-1718, 2026-11-03): the cheapest ZDR host with
          # json_schema (PrimeIntellect, fp4), DeepInfra (bf16) when it's down.
          # require_parameters keeps calls off hosts that would ignore the schema.
          cloud-gptoss-20b = {
            model = "openrouter/openai/gpt-oss-20b";
            extra_body.provider = zdr // {
              only = [ "primeintellect" "deepinfra" ];
              require_parameters = true;
              allow_fallbacks = true;
            };
          };
          # Cheaper frontier candidates for agent work in pis (2026-10-29), ZDR hosts only.
          # V4 Pro's ZDR hosts don't include usHosts' four: DeepInfra, Azure US and Crusoe.
          cloud-deepseek-pro = {
            model = "openrouter/deepseek/deepseek-v4-pro";
            extra_body.provider = zdr // {
              only = [ "deepinfra" "azure" "crusoe" ];
              allow_fallbacks = false;
            };
          };
          # Personal-project twins of the two models ZDR makes pricier: no training on prompts,
          # but the host may keep them a while (abuse review). Not for work or red-team data.
          cloud-deepseek-pro-retain = {
            model = "openrouter/deepseek/deepseek-v4-pro";
            # US hosts only: V4 Pro is also served from China (Baidu, Alibaba, SiliconFlow, StreamLake).
            extra_body.provider = { data_collection = "deny"; only = [ "deepinfra" "crusoe" "azure" ]; allow_fallbacks = false; };
          };
          cloud-gpt-retain = {
            model = "openrouter/openai/gpt-6.1-terra";
            extra_body.provider.data_collection = "deny";
          };
          cloud-grok = {
            model = "openrouter/x-ai/grok-4.20";
            extra_body.provider = zdr;
          };
          cloud-gpt = {
            model = "openrouter/openai/gpt-6.1-terra";
            extra_body.provider = zdr;
          };
          cloud-gemini-flash = {
            model = "openrouter/google/gemini-3.8-flash";
            extra_body.provider = zdr;
          };
        }
        # Claude caches only what a request marks with cache_control, and Pi's OpenAI-style
        # requests carry no marks: without them every turn paid full price for the whole
        # history (measured 2026-10-29). LiteLLM marks the system prompt and the newest
        # message, so each turn reads the history before it from cache.
        // lib.listToAttrs (map
          (m: lib.nameValuePair "cloud-${m}" {
            model = "openrouter/anthropic/claude-${m}-5.5";
            # ZDR serves Claude from Bedrock and Vertex, not Anthropic's own API.
            extra_body.provider = zdr;
            cache_control_injection_points = [
              { location = "message"; role = "system"; }
              { location = "message"; index = -1; }
            ];
          })
          [ "haiku" "sonnet" "opus" ]);
      planner = "cloud-glm";
    };

    # OpenRouter's images API for configs/imagegen (POST /api/v1/images: every image model,
    # reference images, aspect, resolution, seed). LiteLLM has no route for it, so it's passed
    # straight through with the key added here. Merges with ai-stack's own pass-throughs
    # (/openrouter/decisions, /openrouter/key). Image models only, and Tailscale-only.
    services.litellm.settings.general_settings.pass_through_endpoints = [
      {
        path = "/openrouter/images";
        target = "https://openrouter.ai/api/v1/images";
        methods = [ "POST" ];
        headers.Authorization = "bearer os.environ/OPENROUTER_API_KEY";
      }
    ];

    # Claude Code overlay — auto-updating Bun-built binaries direct from
    # Anthropic releases, refreshed hourly. Skips the nixpkgs review lag.
    nixpkgs.overlays = [ inputs.nix-claude-code.overlays.default ];

    # eMudhra intermediates under this root had recoverable private keys
    # (https://harry.id/blog/emudhra-ca-compromise-macos-curl). Browsers block
    # them, but curl/python/git read this bundle. Drop once nixpkgs cacert is patched.
    security.pki.caCertificateBlacklist = [ "emSign ECC Root CA - G3" ];

    # Logitech G502 X PLUS (Lightspeed). Solaar sets DPI, report rate and the
    # onboard profile; buttons live in those profiles (`solaar profiles`, YAML).
    # Piper/libratbag can't drive this mouse yet: its profile format (0x0a)
    # isn't supported upstream (libratbag/libratbag#1655).
    hardware.logitech.wireless = {
      enable = true; # udev rules for the receiver and mouse
      enableGraphical = true; # the Solaar app
    };

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
    # enableIPv6 = false (modules/networking.nix) is undone per interface by NM when a
    # profile has ipv6.method=auto (every saved Wi-Fi), and the router's 6to4 IPv6 has no
    # route out, so apps that try IPv6 first stall. Turn it back off on every up.
    networking.networkmanager.dispatcherScripts = [
      {
        source = pkgs.writeText "no-ipv6" ''
          if [ "$2" = up ] && [ -e "/proc/sys/net/ipv6/conf/$1/disable_ipv6" ]; then
            echo 1 > "/proc/sys/net/ipv6/conf/$1/disable_ipv6"
          fi
        '';
        type = "basic";
      }
    ];
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

    # Internet over the cable (measured 2026-10-24: ~730 vs ~500 Mbit/s on Wi-Fi, 5.8 vs
    # 9 ms jittery), with Wi-Fi as fallback: NM's Wi-Fi default route has metric 600, and
    # a cable-less enp6s0 route is ignored instead of black-holing traffic.
    networking.defaultGateway = {
      address = "192.168.1.1";
      interface = "enp6s0";
      metric = 100;
    };
    boot.kernel.sysctl = {
      "net.ipv4.conf.all.ignore_routes_with_linkdown" = 1;
      # Both NICs sit on 192.168.1.0/24: answer ARP only for the NIC's own address.
      "net.ipv4.conf.all.arp_ignore" = 1;
      "net.ipv4.conf.all.arp_announce" = 2;
    };

    services.tailscale = {
      enable = true;
      # Its own nixpkgs input, refreshed by the weekly auto-upgrade below (stable lags tailscale
      # releases by months; the Mac client comes from brew).
      package = inputs.nixpkgs-tailscale.legacyPackages.${pkgs.stdenv.hostPlatform.system}.tailscale;
      openFirewall = true; # let tailscale traffic in/out
      useRoutingFeatures = "server"; # turns this box into a subnet router
      extraUpFlags = [
        "--advertise-routes=192.168.1.0/24" # <- change if your LAN is different
        "--ssh" # optional, enables Tailscale SSH
      ];
    };

    # Optional but recommended: trust Tailscale interface in your firewall
    networking.firewall.trustedInterfaces = [ "tailscale0" ];

    # Weekly, Sunday evening: rebuild from the last commit with only Tailscale's nixpkgs moved to
    # the newest nixos-unstable (the lock file isn't touched), then garbage-collect down to the
    # new generation (nix.gc in modules/general.nix). Skipped while the repo has uncommitted
    # changes, so a half-done edit never goes live unattended. Runs at next boot if missed.
    # Root builds this ezekiel-owned checkout (the upgrade, and rebuilds run as systemd jobs so
    # a Rex server restart can't cut them off); git refuses another user's repo without this.
    programs.git = {
      enable = true;
      config.safe.directory = [ "/home/ezekiel/Documents/repos/configs" ];
    };
    system.autoUpgrade = {
      enable = true;
      flake = "git+file:///home/ezekiel/Documents/repos/configs#desktop";
      flags = [ "--override-input" "nixpkgs-tailscale" "github:nixos/nixpkgs/nixos-unstable" "--no-write-lock-file" "--impure" ];
      dates = "Sun 20:00";
      randomizedDelaySec = "0";
      persistent = true;
      allowReboot = false;
    };
    systemd.services.nixos-upgrade = {
      preStart = ''
        if [ -n "$(${pkgs.util-linux}/bin/runuser -u ezekiel -- ${pkgs.git}/bin/git -C /home/ezekiel/Documents/repos/configs status --porcelain --untracked-files=no -- . ':!result')" ]; then
          echo "configs has uncommitted changes; skipping this week's upgrade" >&2
          exit 1
        fi
      '';
      unitConfig.OnSuccess = [ "nix-gc.service" ];
    };
  };
}
