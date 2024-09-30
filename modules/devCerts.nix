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
MIIDDDCCAfSgAwIBAgIIPVCQVOiZtx4wDQYJKoZIhvcNAQELBQAwFDESMBAGA1UE
AxMJbG9jYWxob3N0MB4XDTI0MDkyMzE2NDkzMFoXDTI1MDkyMzE2NDkzMFowFDES
MBAGA1UEAxMJbG9jYWxob3N0MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKC
AQEA0dQTGckbedm4C64fdnefUbmPynaqZ9ayY0vais58CO+ocF8fn41C916/XP5M
dnLqTxExmxCeaD/FPoZp53kAitc5NuzFKVRrgQ7Ma3shjQlWcuN5y0fo1W8iN70R
np1Nb/QQXrdG2hUIiWwX5iCwyMjGmoCzY4i3IZCBzqYXSYJ9m1NH+dzgUGPvA7jW
P1wDtjVC1JVxko+ctkCloguGt7mMJaMPO0K9sGERJIUhVfqFFccAK6YwcWpjQSji
SESoXfo6bULKC+fw+rjVe4dWS8279jre/laS46A47Yht5XHCfZ0T/tp1WcS3jPy/
3LsMz6NgOAjK1O4QRjDF5PMIiwIDAQABo2IwYDAMBgNVHRMBAf8EAjAAMA4GA1Ud
DwEB/wQEAwIFoDAWBgNVHSUBAf8EDDAKBggrBgEFBQcDATAXBgNVHREBAf8EDTAL
gglsb2NhbGhvc3QwDwYKKwYBBAGCN1QBAQQBAjANBgkqhkiG9w0BAQsFAAOCAQEA
Hfqd8HPMIbbdIyR90LAJvIfULPJfh5zXpoatwCPYcwKHe4LBELMFUnZDT4gVNKCg
LhpcfJSGqSWNkAH6CQGPa46KN5aRW4F452gkhtNH1xm86ambaarWXJGtn2Qcb543
tvZElpz8aGjJ0MHY5+x2Ro2vhV962iv4WagWF8zOFmTkmwrQFLFaV9ef1grRx3MQ
bokY0JdkRSRW5YvUFmCb3yf2gIqOkqtGFhs0oh2DlYMaH0PWE0ahiogF+uWxI6Fa
L7Fmz3CgozPuPZq2DvmjSTVGrS6zNYXlCMvIVX38chZYpl2WdviJfv78MHv6U2Tw
u+ekUPiK6fYuUUSLdXoRaw==
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
