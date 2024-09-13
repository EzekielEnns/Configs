{ ... }:
{
# this is the only way i have found to get dotnet dev-certs to work on nixos 
# particularly  in relation to the CA and allowing cross communication between apps
#https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-dev-certs
#https://learn.microsoft.com/en-us/dotnet/core/additional-tools/self-signed-certificates-guide#with-openssl
# this is all cause i cant run updateCA
#https://stackoverflow.com/questions/44159793/trusted-root-certificates-in-dotnet-core-on-linux-rhel-7-1
#use full commands for debugging `sudo openssl x509 -noout -text -in *.pem`

#try name of cert
#please note these are generated from the command `dotnet dev-certs https -ep *.crt --format Pem`
      security.pki.certificates= [
      ''
-----BEGIN CERTIFICATE-----
MIIDDDCCAfSgAwIBAgIIfiuB8BpOi+cwDQYJKoZIhvcNAQELBQAwFDESMBAGA1UE
AxMJbG9jYWxob3N0MB4XDTI0MDUwODE0MjQxNFoXDTI1MDUwODE0MjQxNFowFDES
MBAGA1UEAxMJbG9jYWxob3N0MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKC
AQEArlV0JoiSojI5bSlFca225Skhu3irWScB+vZ/2kWoxFTUqQoLJSI62GG5T7OK
VvEERZ6JLgq/5aVKFl50ZPoo2FgZoCE6WaLMctNywsgUbS/yqnykdemV9lX4wD2L
Q6l4KLwh339OUHvTIS47qGjIm/lNAU28TPVjcuyprk1zR5POYRZSFwqF6VJLohFi
JEW8W4nTV59V48BfHmAXDSidZoy8SoJsu4v50EzFVZpXvz6qS6g6OJ/oWDzjLwb2
sKnyVOD9igpMFm25nWXMVheXCYAg42f1DxN85fNDHANq9zNkUZ+FCqsfrCFl9eD/
g2w6xAlisIqiZdJCLMpm4vb5aQIDAQABo2IwYDAMBgNVHRMBAf8EAjAAMA4GA1Ud
DwEB/wQEAwIFoDAWBgNVHSUBAf8EDDAKBggrBgEFBQcDATAXBgNVHREBAf8EDTAL
gglsb2NhbGhvc3QwDwYKKwYBBAGCN1QBAQQBAjANBgkqhkiG9w0BAQsFAAOCAQEA
ifWMQ/vSfEKr4OcFkdmbB/TxAXALs6EZvIo++X+Z/EZtstFwrK4ilqcFRqyy/2Yo
OBdIGkeymCkywaUjsJscbvYUwG+K5mu6QtdHuHTE85z3ie++zpWB1hJBrsDeHxev
vcnVWRgusT/vM9GcER33OJfLcPl3yXMHUSyKV4qvJZxRx25AUiir6VpwL0VpusQV
CsA3GLKpnr7o0jcQYxQgw7jcko2d2ALqarL9Fa4r7XsZ7mgPfaDCOKXKf68FIYn2
jPWA/ng8kpMdCdppAzK3FODETRdeI4eZY2sT2YcLx9S7DdXKHjp8f5pgkP1Cpi5F
Kw5XtPzIxuU2D3oCEUzxug==
-----END CERTIFICATE-----
      ''
      ''
-----BEGIN CERTIFICATE-----
MIIDDTCCAfWgAwIBAgIJAMr9KMvSXiSCMA0GCSqGSIb3DQEBCwUAMBQxEjAQBgNV
BAMTCWxvY2FsaG9zdDAeFw0yNDA2MTcxNjIwNDRaFw0yNTA2MTcxNjIwNDRaMBQx
EjAQBgNVBAMTCWxvY2FsaG9zdDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoC
ggEBALALB2RU4V7X5qSZBArW3yLJnycv3u84xVglFjhfRQr/1JUiV8o2HGruiBZZ
sOp1jAkA4dBz7bo+Ra3BU4Sngtbkm6uZLnITZkGjn/aCeYTodope2gQxWKNv5zyt
7lGFMLkrKJHMEoBv1Y+wR1J8mwjFu1bAuwczaE/xT7aoiq6BBiUyB8nD8Js2z45X
nQLRq2BtFcuEZbKAaLoeTmKOPrzIFAXBvrDmUo6Payai02RsdgLqK0iKMxvw5T6K
9perqzmhQZRB0gTr5pJha9lvQZT+YoVPgf3s8TSRL4mHoEMKmdeJpCrvCrXR2jx8
e9JwrSzSBdUqbiPW33bBdSCPpHUCAwEAAaNiMGAwDAYDVR0TAQH/BAIwADAOBgNV
HQ8BAf8EBAMCBaAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwEwFwYDVR0RAQH/BA0w
C4IJbG9jYWxob3N0MA8GCisGAQQBgjdUAQEEAQIwDQYJKoZIhvcNAQELBQADggEB
AEtxFazFeUXhzwWYbjOD0Sq+xuycvyKGthrwnVSskmKu7erXjj+bRZcCf9Dxykhd
argCh/WRqzFKNbZsXrMdnRsSunyYiKhoQPHRuKRr73go3SW7LHBSyCqyKditrpMi
7I7fF30OeZWqQ77uCNt6kRzAqJBAsz2uHyO+sEJk4SXJ0TD71uDOhfaqKp1ngjZR
/msd8endDkZySJNJXxLZ7uVxKQIx1d0E4PvmXX13s6uaRQAJFEM0s2iIjRnAYyXB
ojmwiIKZuS+MlqlZHGUgqX0FwGtBypkFn0qn0S0Rw03Aipd8wlfT5luri/WJQljR
PH+Svl2qOJ0stcDmainVmBM=
-----END CERTIFICATE-----
      ''
      ];

#my attempts 
      # security.pki.certificateFiles = [
      #     /usr/local/share/ca-certificates/aspnet/https.crt
      #   ];
      #TODO this is for dev envs-- find way to make this more secure
      # security.acme = {
      #     defaults.email = "ezekiel.enns@protonmail.com";
      #     acceptTerms = true;
      #     preliminarySelfsigned = true;
      #     defaults.dnsPropagationCheck = false;
      #     certs = {
      #       "devA" = {
      #           keyType = "RSA4096";
      #           domain = "contoso.com";
      #           dnsPropagationCheck = false;
      #       };
      #     };
      # };
    #   security.acme = {
    #       acceptTerms = true;
    #       defaults = {
    #         email = "ezekiel.enns@protonmail.com";
    #         dnsPropagationCheck = false;
    #         keyType = "rsa4096";
    #       };
    #       preliminarySelfsigned = true;
    # certs = {
    #   "devB" = {
    #     webroot = "contoso.com";
    #     keyType = "rsa4096";
    #     #extraLegoRunFlags = [ "--key-type rsa4096" ];
    #     extraLegoFlags = [ "--pfx" "--pfx.pass" "pass" "--pfx.format" "SHA256" ];
    #   };
    # };
    #       # certs = {
    #       #   "devA" = {
    #       #     domain = "contoso.com" ;
    #       #     dnsPropagationCheck = false;
    #       #   };
    #       # };
    #     };
  # environment.etc."webroot".source = "/var/lib/acme/webroot";
  #
  # # Create the directory if it doesn't exist
  # systemd.tmpfiles.rules = [
  #   "d /var/lib/acme/webroot 0755 http http -"
  # ];
      # security.acme.defaults.email = "ezekiel.enns@protonmail.com";
      # security.acme.acceptTerms = true;
      # security.acme.certs = {
      #     "devcerta" = {
      #       webroot = "/var/lib/acme/ckA";
      #     };
      #     "devcertb" = {
      #       webroot = "/var/lib/acme/ckB";
      #     };
      # };
}
