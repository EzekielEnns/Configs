{ config, pkgs,  ... }:
{
    services.step-ca = {
        enable = true;
        address = "127.0.0.1:9000";  # local only
    };

    # Use NixOS ACME client against your private step-ca ACME directory
    # URL format: https://<ca-host>:<port>/acme/<provisioner-name>/directory
    security.acme = {
        acceptTerms = true;
        defaults = {
            email = "zeek.enns@pm.me";
            server = "https://127.0.0.1:9000/acme/acme/directory";
            # Let NixOS place HTTP-01 challenges under a shared webroot nginx will serve
            webroot = "/var/lib/acme/.well-known";
            group = "nginx";
        };
        certs = {
            "xng.home.arpa" = { domain = "xng.home.arpa"; };
            "ai.home.arpa"  = { domain = "ai.home.arpa"; };
            "mm.home.arpa"  = { domain = "mm.home.arpa"; };
            "jf.home.arpa"  = { domain = "jf.home.arpa"; };
        };
    };

    services.nginx = {
        enable = true;
        recommendedProxySettings = true;
        recommendedTlsSettings = true;
        # Nginx will automatically serve the ACME webroot at /.well-known/acme-challenge
        # when you use useACMEHost/enableACME.
        virtualHosts = {
            #reserved domain, actually pretty cool
            #https://en.wikipedia.org/wiki/.arpa#Residential_networking
            "xng.home.arpa" = {
                forceSSL = true;
                # Use a unique local domain name for each service
                serverName = "xng.home.arpa";
                # Define the proxy pass to the internal port
                locations."/" = {
                    proxyPass = "http://127.0.0.1:8088";
                };
            };
            "ai.home.arpa" = {
                serverName = "ai.home.arpa";
                forceSSL = true;
                locations."/" = {
                    proxyPass = "http://127.0.0.1:8080";
                    # Required for WebSocket connections used by Open WebUI
                    proxyWebsockets = true;
                };
            };
            "mm.home.arpa" = {
                serverName = "mm.home.arpa";
                forceSSL = true;
                locations."/" = {
                    proxyPass = "http://127.0.0.1:5230";
                };
            };
            "jf.home.arpa" = {
                serverName = "jf.home.arpa";
                forceSSL = true;
                locations."/" = {
                    proxyPass = "http://127.0.0.1:8096";
                };
            };
        };
    };
    #Note on macos you need to set this as your dns ..... fml i hate macos
    services.dnsmasq = {
        enable = true;

        # Don't point this host at itself unless you want local DNS resolution
        # via /etc/resolv.conf. Most folks keep this off.
        resolveLocalQueries = false;  # prevents touching resolv.conf

        settings = {
            # Bind on loopback + your LAN IP
            "listen-address" = [ "127.0.0.1" "192.168.1.6" ];

            # Upstream resolvers (Cloudflare)
            server = [ "1.1.1.1" "1.0.0.1" ];

            # Pin local names to your host's LAN IP
            address = [
                "/ca.home.arpa/192.168.1.6"
                "/xng.home.arpa/192.168.1.6"
                "/ai.home.arpa/192.168.1.6"
                "/mm.home.arpa/192.168.1.6"
                "/jf.home.arpa/192.168.1.6"
            ];

            # Sensible DNS hygiene
            "domain-needed" = true;
            "bogus-priv"   = true;
            # "bind-interfaces" = true;  # uncomment if you want strict binding
        };
    };

    # If other devices on your LAN should use this box for DNS:
    networking.interfaces.enp6s0.wakeOnLan = {
        enable = true;
    };
    networking.networkmanager.enable = true;
    networking.networkmanager.unmanaged = ["enp6s0"];
    networking.firewall.allowedUDPPorts = [ 53 ];
    networking.firewall.allowedTCPPorts = [ 53 8096  22 80 443 11434 8554 9000  ];

    services.ollama = {
        enable = true;
        acceleration = "cuda";
        host = "0.0.0.0";
    };

    services.jellyfin.enable = true;
    systemd.tmpfiles.rules = [
        # World-writable + sticky bit (1xxx). Owned by root is typical.
        "d /srv/media         1777 root root - -"
        "d /srv/media/movies  1777 root root - -"
        "d /srv/media/tv      1777 root root - -"
        "d /srv/media/anime   1777 root root - -"
        "d /srv/media/shows   1777 root root - -"
        # Ensure/repair ownership & mode at boot (recursively for the top dir)
        "Z /srv/media         1777 root root - -"
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
        steam-hardware.enable = true;
        #Every 1.0s: nvidia-smi
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
                nvidiaBusId = "PCI:1:0:0";  # from 01:00.0
            };
        };
    };
    services.xserver.videoDrivers = [ "amdgpu" "nvidia"];


# /etc/searxng/settings.yml will be generated by Nix
environment.etc."searxng/settings.yml".text = ''
use_default_settings: true

server:
  secret_key: "ba84d4236c87f611e894c4e5dedb88c8ab9632bc868cc521bbdb84ce1f625232"

search:
  formats: [html, json]

doi_resolvers:
  doi.org: "https://doi.org/"
default_doi_resolver: "doi.org"
'';

    virtualisation.docker.enable = true;


    virtualisation.oci-containers = {
        backend = "docker";
        containers = {
            searxng = { 
                image = "searxng/searxng:latest";
                ports = [ "127.0.0.1:8088:8080" ];
                volumes = [ "/etc/searxng/settings.yml:/etc/searxng/settings.yml:ro" ];
                environment = { SEARXNG_SETTINGS_PATH = "/etc/searxng/settings.yml"; };
            };


            openwebui = {
                image = "ghcr.io/open-webui/open-webui:main";
                extraOptions = [ "--network=host" ];
                volumes = [ "/var/lib/openwebui:/app/backend/data" ];
                environment = { 
                    RAG_WEB_SEARCH_ENGINE = "searxng";
                    RAG_WEB_SEARCH_RESULT_COUNT = "3";
                    RAG_WEB_SEARCH_CONCURRENT_REQUESTS = "10";
                    SEARXNG_QUERY_URL = "http://127.0.0.1:8088/search?q=<query>&format=json";
                    OLLAMA_BASE_URL = "http://localhost:11434"; 
                };
            };
            memos = {
                image = "neosmemo/memos:stable";
                ports = [ "127.0.0.1:5230:5230" ];
                volumes = [ "/var/lib/memos:/var/opt/memos" ];
            };
        };
    };


}

