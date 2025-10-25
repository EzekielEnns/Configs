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
              "code"
            ];
            cmd =
              "${llamaServer} --host 127.0.0.1 --port \${PORT} "
              + "-m /var/lib/llama-cpp/models/Devstral-Small-2507-UD-Q4_K_XL.gguf "
              + "--jinja "
              + "-ngl 99 -c 4096 -b 1024  --parallel 1";
          };
          "Llama3Tadashinu.Q4_K_M" = {
            aliases = [
              "friend"
            ];
            cmd =
              "${llamaServer} --host 127.0.0.1 --port \${PORT} "
              + "-m /var/lib/llama-cpp/models/Llama3Tadashinu.Q4_K_M.gguf "
              + "--jinja "
              + "-ngl 999 -c 8192 -b 1024 --parallel 1";
          };
          "DarkIdol" = {
            aliases = [
              "smutty"
            ];
            #https://huggingface.co/QuantFactory/DarkIdol-Llama-3.1-8B-Instruct-1.2-Uncensored-GGUF
            cmd = # takes up 9gb of vram
              "${llamaServer} --host 127.0.0.1 --port \${PORT} "
              + "-m /var/lib/llama-cpp/models/DarkIdol-Llama-3.1-8B-Instruct-1.2-Uncensored.Q8_0.gguf "
              + "--jinja "
              + "-ngl 999 -c 8192 -b 1024 --parallel 1";
          };
          "baronllm-llama3.1-v1-q6_k" = {
            aliases = [
              "hacking"
            ];
            cmd =
              "${llamaServer} --host 127.0.0.1 --port \${PORT} "
              + "-m /var/lib/llama-cpp/models/baronllm-llama3.1-v1-q6_k.gguf "
              + "--jinja "
              + "-ngl 99 -c 4096 -b 1024  --parallel 1";
          };
          "Mistral-Small-3.2-24B-Instruct-2506-Q4_K_M" = {
            aliases = [
              "g-4m"
            ];
            cmd =
              "${llamaServer} --host 127.0.0.1 --port \${PORT} "
              + "-m /var/lib/llama-cpp/models/Mistral-Small-3.2-24B-Instruct-2506-Q4_K_M.gguf "
              + "--jinja "
              + "-ngl 99 -c 4096 -b 1024  --parallel 1";
          };
          "Mistral-Small-3.2-24B-Instruct-2506-Q4_K_S" = {
            aliases = [
              "g-4s"
            ];
            cmd =
              "${llamaServer} --host 127.0.0.1 --port \${PORT} "
              + "-m /var/lib/llama-cpp/models/Mistral-Small-3.2-24B-Instruct-2506-Q4_K_S.gguf "
              + "--jinja "
              + "-ngl 99 -c 4096 -b 1024  --parallel 1";
          };
          "Mistral-Small-3.2-24B-Instruct-2506-Q4_K_XL" = {
            aliases = [
              "g-4xl"
            ];
            cmd =
              "${llamaServer} --host 127.0.0.1 --port \${PORT} "
              + "-m /var/lib/llama-cpp/models/Mistral-Small-3.2-24B-Instruct-2506-UD-Q4_K_XL.gguf "
              + "--jinja "
              + "-ngl 99 -c 4096 -b 1024  --parallel 1";
          };
          "pivot-10.7b-mistral-v0.2-rp.8" = {
            aliases = [
              "t1"
            ];
            cmd =
              "${llamaServer} --host 127.0.0.1 --port \${PORT} "
              + "-m /var/lib/llama-cpp/models/pivot-10.7b-mistral-v0.2-rp.Q8_0.gguf "
              + "--jinja "
              + "-ngl 999 -c 8192 -b 1024 --parallel 1";
          };
          "Hermes-3-Llama-3.1-8B-Q8_0" = {
            aliases = [
              "t2"
            ];
            cmd =
              "${llamaServer} --host 127.0.0.1 --port \${PORT} "
              + "-m /var/lib/llama-cpp/models/Hermes-3-Llama-3.1-8B-Q8_0.gguf "
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
    services.dnsmasq = {
      enable = true;
      resolveLocalQueries = false;

      settings = {
        # keep your existing settings ↓
        "listen-address" = [
          "127.0.0.1"
          "192.168.1.6"
        ];
        server = [
          "1.1.1.1"
          "1.0.0.1"
        ];
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
        "domain-needed" = true;
        "bogus-priv" = true;

        # === PXE/iPXE bits ===
        enable-tftp = true;
        tftp-root = "/srv/tftp";

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
    networking.networkmanager.unmanaged = [ "enp6s0" ];
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
  };
}
