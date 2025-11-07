{ lib
, config
, inputs
, pkgs
, pkgs-unstable
, ...
}:
let
  llamaCuda = pkgs.llama-cpp.override { cudaSupport = true; };
  llamaServer = lib.getExe' llamaCuda "llama-server";
in
{
  imports = [
    (import "${inputs.nixpkgs-unstable}/nixos/modules/services/networking/llama-swap.nix")
  ];
  config = {
    environment.systemPackages = [
      llamaCuda
      pkgs.lm_sensors
      pkgs.glances
      pkgs.htop
      pkgs.nvtopPackages.full
      pkgs.btop
    ];
    services.llama-swap = {
      enable = true;
      port = 9292; # single public endpoint for all models
      package = pkgs-unstable.llama-swap;

      # This mirrors llama-swap's config.yaml, but as Nix attrs
      settings = {
        healthCheckTimeout = 60;
        models = {
          "Devstral-Small-2507" = {
            aliases = [
              "coding"
            ];
            cmd =
              "${llamaServer} --host 127.0.0.1 --port \${PORT} "
              + "-m /var/lib/llama-cpp/models/Devstral-Small-2507-UD-Q4_K_XL.gguf "
              + "--flash-attn "
              + "--mlock "
              + "--cont-batching "
              + "--gpu-layers 999 ";
          };
          "Sauske" = {
            cmd =
              "${llamaServer} --host 127.0.0.1 --port \${PORT} "
              + "-m /var/lib/llama-cpp/models/Llama3Tadashinu.Q4_K_M.gguf "
              + "--flash-attn "
              + "--mlock "
              + "--cont-batching "
              + "--gpu-layers 999 ";
          };
          "Cloe-horror" = {
            cmd =
              "${llamaServer} --host 127.0.0.1 --port \${PORT} "
              + "-m /var/lib/llama-cpp/models/Gemma-3-12b-it-MAX-HORROR-D_AU-Q8_0-imat.gguf "
              + "--flash-attn "
              + "--mlock "
              + "--cont-batching "
              + "--gpu-layers 999 ";
          };
          "Cloe-hero" = {
            cmd =
              "${llamaServer} --host 127.0.0.1 --port \${PORT} "
              + "-m /var/lib/llama-cpp/models/L3.1-RP-Hero-BigTalker-8B-D_AU-Q8_0.gguf "
              + "--flash-attn "
              + "--mlock "
              + "--cont-batching "
              + "--gpu-layers 999 ";
          };
          "Cloe-NemoBigThot" = {
            cmd =
              "${llamaServer} --host 127.0.0.1 --port \${PORT} "
              + "-m /var/lib/llama-cpp/models/Llama-3.1-Nemotron-Nano-8B-v1-BF16.gguf "
              + "--flash-attn "
              + "--mlock "
              + "--cont-batching "
              + "--gpu-layers 999 ";
          };
          "Cloe-NemoLessThot" = {
            cmd =
              "${llamaServer} --host 127.0.0.1 --port \${PORT} "
              + "-m /var/lib/llama-cpp/models/Llama-3.1-Nemotron-Nano-8B-v1-UD-Q8_K_XL.gguf "
              + "--flash-attn "
              + "--mlock "
              + "--cont-batching "
              + "--gpu-layers 999 ";
          };
          "Cloe-dolphin-Solth-Llama3" = {
            cmd =
              "${llamaServer} --host 127.0.0.1 --port \${PORT} "
              + "-m /var/lib/llama-cpp/models/dolphin-llama3-zh-cn-uncensored-unsloth.Q8_0.gguf "
              + "--flash-attn "
              + "--mlock "
              + "--cont-batching "
              + "--gpu-layers 999 ";
          };
          "DarkIdol" = {
            cmd =
              "${llamaServer} --host 127.0.0.1 --port \${PORT} "
              + "-m /var/lib/llama-cpp/models/DarkIdol-Llama-3.1-8B-Instruct-1.2-Uncensored.Q8_0.gguf "
              + "--flash-attn "
              + "--mlock "
              + "--cont-batching "
              + "--gpu-layers 999 ";
          };
          "Cloe-pivot-10.7b-mistral-v0.2-rp.8" = {
            cmd =
              "${llamaServer} --host 127.0.0.1 --port \${PORT} "
              + "-m /var/lib/llama-cpp/models/pivot-10.7b-mistral-v0.2-rp.Q8_0.gguf "
              + "--flash-attn "
              + "--mlock "
              + "--cont-batching "
              + "--gpu-layers 999 ";
          };
          "baronllm-llama3.1-v1-q6_k" = {
            aliases = [
              "hacking"
            ];
            cmd =
              "${llamaServer} --host 127.0.0.1 --port \${PORT} "
              + "-m /var/lib/llama-cpp/models/baronllm-llama3.1-v1-q6_k.gguf "
              + "--flash-attn "
              + "--mlock "
              + "--cont-batching "
              + "--gpu-layers 999 ";
          };
        };
      };
    };

    services.jellyfin = {
      enable = true;
      group = "media";
    };

    users.groups.media = { };
    users.users.ezekiel.extraGroups = [ "media" ];
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

      "d /srv/tftp 0755 root root -"
      "d /var/www/ipxe 0755 root root -"
    ];

    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = true;
        PermitRootLogin = "yes";
        X11Forwarding = true;
      };
    };

    hardware = {
      graphics = {
        enable = true;
        enable32Bit = true;
      };
      nvidia-container-toolkit.enable = true;
      steam-hardware.enable = true;
      #show gpu temps  watch -n0.5 nvidia-smi
      # nix-shell -p pciutils --run "lspci | grep -E 'VGA|3D'"
      nvidia = {
        modesetting.enable = true;
        powerManagement.enable = true;
        open = false;
        nvidiaSettings = true;
        package = config.boot.kernelPackages.nvidiaPackages.production;
        prime = {
          offload.enable = true;
          amdgpuBusId = "PCI:15:0:0"; # from 0f:00.0
          nvidiaBusId = "PCI:1:0:0"; # from 01:00.0
        };
      };
    };
    services.xserver.videoDrivers = [
      "amdgpu"
      "nvidia"
    ];
    virtualisation.docker.enable = true;
    virtualisation.docker.enableOnBoot = true;

    virtualisation.docker.daemon.settings = {
      features.cdi = true;
    };
    virtualisation.oci-containers = {
      backend = "docker";
      containers = {
        owui = {
          extraOptions = [ "--network=host" ];
          ports = [ "8080" ];
          image = "ghcr.io/open-webui/open-webui:main";
          volumes = [ "/var/lib/openwebui:/app/backend/data" ];
          environment = {
            WEBUI_AUTH = "false";
            OPENAI_API_BASE_URL = "http://ai.lan/v1";
          };
        };
        docsMcp = {
          image = "ghcr.io/arabold/docs-mcp-server:latest";
          # Host networking = no need for ports mapping, and the container can use 127.0.0.1:9002
          extraOptions = [ "--network=host" ];

          ports = [ "6280:6280" ];
          # Persist the index
          volumes = [ "/var/lib/docs-mcp:/data" ];

          # Env to use your local llama.cpp embeddings server
          environment = {
            DOCS_MCP_HOST = "0.0.0.0";
            DOCS_MCP_PORT = "6280";
            OPENAI_API_BASE = "http://127.0.0.1:9002/v1";
            OPENAI_API_KEY = "none";
            DOCS_MCP_EMBEDDING_MODEL = "embed";
            NODE_ENV = "production";
          };

          # Same flags you had in docker run (+no telemetry)
          cmd = [
            "--protocol"
            "http"
            "--host"
            "0.0.0.0"
            "--port"
            "6280"
            "--no-telemetry"
          ];
        };

        qbittorrent = {
          extraOptions = [ "--network=host" ];
          image = "lscr.io/linuxserver/qbittorrent:latest";
          volumes = [
            "/srv/media/torrents:/downloads" # downloads land here
            "/var/qbit/config:/config"
          ];
          ports = [
            "8083:8083"
            "6881:6881"
            "6881:6881/udp"
          ];
          environment = {
            WEBUI_PORT = "8083";
          };
        };
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
        sillyTavern = {
          image = "ghcr.io/sillytavern/sillytavern:latest";
          volumes = [
            "/var/lib/silly/config:/home/node/app/config:rw"
            "/var/lib/silly/app/data:/home/node/app/data:rw"
            "/var/lib/silly/extensions:/home/node/app/public/scripts/extensions/third-party:rw"
            "/var/lib/silly/plugins:/home/node/app/plugins:rw"
          ];
          ports = [ "127.0.0.1:8081:8000" ];
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
        "wui.lan" = {
          serverName = "wui.lan";
          locations."/" = {
            proxyPass = "http://127.0.0.1:8080";
            proxyWebsockets = true;
          };
        };
        "st.lan" = {
          serverName = "st.lan";
          locations."/" = {
            proxyPass = "http://127.0.0.1:8081";
            proxyWebsockets = true;
          };
        };
        "jf.lan" = {
          serverName = "jf.lan";
          locations."/" = {
            proxyPass = "http://127.0.0.1:8096";
            proxyWebsockets = true;
          };
        };
        "ai.lan" = {
          serverName = "ai.lan";
          locations."/" = {
            proxyPass = "http://127.0.0.1:9292";
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
    services.dnscrypt-proxy2 = {
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
          #          "/lan/" # resolves to local domain
        ];
        local = [ "/lan/" ];
        address = [
          "/qb.lan/192.168.1.6"
          "/sb.lan/192.168.1.6"
          "/st.lan/192.168.1.6"
          "/jf.lan/192.168.1.6"
          "/dc.lan/192.168.1.6"
          "/ai.lan/192.168.1.6"
          "/wui.lan/192.168.1.6"
          "/ex.lan/192.168.1.6"
          "/mb.lan/192.168.1.6"
          # add a name for your HTTP iPXE vhost
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
    networking.firewall.allowedUDPPorts = [
      53
      6881
      67
      69
    ];
    networking.firewall.allowedTCPPorts = [
      #dns
      53
      #jf
      8096
      #ssh
      22
      #http
      80
      443
      # 11434
      # 8554
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
  };
}
