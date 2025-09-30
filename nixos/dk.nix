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
    ];
    systemd.services.llama-embed = {
      description = "llama.cpp Embedding Model Server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      # Run as a safe user that can read the model file
      serviceConfig = {
        User = "nobody";
        Group = "nogroup";

        ExecStart = lib.mkForce ''
          ${llamaCuda}/bin/llama-server \
            -m /var/lib/llama-cpp/models/Qwen3-Embedding-0.6B-Q8_0.gguf \
            --host 0.0.0.0 \
            --port 9002 \
            --embedding \
            -ngl 0 \
            -c 2048 \
            --pooling cls
        '';

        # Optional: set a safe working dir
        WorkingDirectory = "/var/lib/llama-cpp";
      };
    };
    services.llama-swap = {
      enable = true;
      port = 9292; # single public endpoint for all models
      package = pkgs-unstable.llama-swap;

      # This mirrors llama-swap's config.yaml, but as Nix attrs
      settings = {
        healthCheckTimeout = 60;
        models = {
          # Coding model (your old services.llama-cpp @9001)
          "Devstral-Small-2507" = {
            aliases = [
              "code"
            ];
            cmd =
              "${llamaServer} --host 127.0.0.1 --port \${PORT} "
              + "-m /var/lib/llama-cpp/models/Devstral-Small-2507-UD-Q4_K_XL.gguf "
              + "--jinja "
              + "-ngl 99 -c 4096 -b 1024  --parallel 1";
          };
          "pivot-10.7b-mistral-v0.2-rp.8" = {
            aliases = [
              #"silly"
            ];
            cmd =
              "${llamaServer} --host 127.0.0.1 --port \${PORT} "
              + "-m /var/lib/llama-cpp/models/pivot-10.7b-mistral-v0.2-rp.Q8_0.gguf "
              + "--jinja "
              + "-ngl 999 -c 8192 -b 1024 --parallel 1";
          };
          "mythomax-l2-13b.Q8_K_M" = {
            aliases = [
              #"silly"
            ];
            cmd =
              "${llamaServer} --host 127.0.0.1 --port \${PORT} "
              + "-m /var/lib/llama-cpp/models/mythomax-l2-13b.Q8_0.gguf "
              + "--jinja "
              + "-ngl 999 -c 8192 -b 1024 --parallel 1";
          };
          "mythomax-l2-13b.Q4_K_M" = {
            aliases = [
              #"silly"
            ];
            cmd =
              "${llamaServer} --host 127.0.0.1 --port \${PORT} "
              + "-m /var/lib/llama-cpp/models/mythomax-l2-13b.Q4_K_M.gguf "
              + "--jinja "
              + "-ngl 999 -c 8192 -b 1024 --parallel 1";
          };
          "MN-12B-Mag-Mell-Q4_K_M" = {
            aliases = [
              #"silly"
            ];
            cmd =
              "${llamaServer} --host 127.0.0.1 --port \${PORT} "
              + "-m /var/lib/llama-cpp/models/MN-12B-Mag-Mell-Q4_K_M.gguf "
              + "--jinja "
              + "-ngl 999 -c 8192 -b 1024 --parallel 1";
          };
          "Llama3Tadashinu.Q4_K_M" = {
            aliases = [
              #"silly"
            ];
            cmd =
              "${llamaServer} --host 127.0.0.1 --port \${PORT} "
              + "-m /var/lib/llama-cpp/models/Llama3Tadashinu.Q4_K_M.gguf "
              + "--jinja "
              + "-ngl 999 -c 8192 -b 1024 --parallel 1";
          };
          "Dark-Champion-Inst-18.4B-Q4_k_m" = {
            aliases = [
              #"silly"
            ];
            cmd =
              "${llamaServer} --host 127.0.0.1 --port \${PORT} "
              + "-m /var/lib/llama-cpp/models/L3.2-8X3B-MOE-Dark-Champion-Inst-18.4B-uncen-ablit_D_AU-Q4_k_m.gguf "
              + "--jinja "
              + "-ngl 999 -c 8192 -b 1024 --parallel 1";
          };
          "Hermes-3-Llama-3.1-8B-Q8_0" = {
            aliases = [
              #"silly"
            ];
            cmd =
              "${llamaServer} --host 127.0.0.1 --port \${PORT} "
              + "-m /var/lib/llama-cpp/models/Hermes-3-Llama-3.1-8B-Q8_0.gguf "
              + "--jinja "
              + "-ngl 999 -c 8192 -b 1024 --parallel 1";
          };
          "DarkIdol" = {
            aliases = [
              #"silly"
            ];
            cmd =
              "${llamaServer} --host 127.0.0.1 --port \${PORT} "
              + "-m /var/lib/llama-cpp/models/DarkIdol-Llama-3.1-8B-Instruct-1.2-Uncensored.Q8_0.gguf "
              + "--jinja "
              + "-ngl 999 -c 8192 -b 1024 --parallel 1";
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
      "d /srv/media         2775 root    media - -"
      "Z /srv/media         2775 root    media - -"

      "d /srv/media/movies  2775 root    media - -"
      "d /srv/media/tv      2775 root    media - -"
      "d /srv/media/anime   2775 root    media - -"
      "d /srv/media/shows   2775 root    media - -"
      "d /var/lib/llama-cpp/models   2775 root    media - -"

      "d /srv/media/torrents 2775 ezekiel media - -"

      "A /srv/media          -    -       -    - g:media:rwx"
      "A /srv/media          -    -       -    - d:g:media:rwx"
      "A /srv/media/torrents - - - - g:media:rwx"
      "A /srv/media/torrents - - - - d:g:media:rwx"
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
        #TODO make account
        qbittorrent = {
          extraOptions = [ "--network=host" ];
          image = "lscr.io/linuxserver/qbittorrent:latest";
          #ports = [ "8083:8080" "6881:6881" "6881:6881/udp" ];
          volumes = [
            "/srv/media/torrents:/downloads" # downloads land here
            "/var/qbit/config:/config"
          ];
          environment = {
            WEBUI_PORT = "8083";
          };
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
        "st.lan" = {
          serverName = "st.lan";
          locations."/" = {
            proxyPass = "http://127.0.0.1:8081";
            proxyWebsockets = true;
          };
        };
        "la.lan" = {
          serverName = "la.lan";
          locations."/" = {
            proxyPass = "http://127.0.0.1:8080";
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
    services.dnsmasq = {
      enable = true;

      resolveLocalQueries = false;

      settings = {
        # Bind on loopback + your LAN IP
        "listen-address" = [
          "127.0.0.1"
          "192.168.1.6"
        ];

        # Upstream resolvers (Cloudflare) -> lets you check online with real dns
        server = [
          "1.1.1.1"
          "1.0.0.1"
        ];

        # Pin local names to your host's LAN IP
        address = [
          #"/xng.lan/192.168.1.6"
          #"/ai.lan/192.168.1.6"
          #"/mm.lan/192.168.1.6"
          "/qb.lan/192.168.1.6"
          "/sb.lan/192.168.1.6"
          "/st.lan/192.168.1.6"
          "/la.lan/192.168.1.6"
          "/jf.lan/192.168.1.6"
          "/dc.lan/192.168.1.6"
          "/ai.lan/192.168.1.6"
        ];

        # Sensible DNS hygiene
        "domain-needed" = true;
        "bogus-priv" = true;
      };
    };

    networking.interfaces.enp6s0.wakeOnLan = {
      enable = true;
    };
    networking.networkmanager.enable = true;
    networking.networkmanager.unmanaged = [ "enp6s0" ];
    networking.firewall.allowedUDPPorts = [
      53
      6881
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
  };
}
