{ ... }:
{
  sops = {
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    defaultSopsFile = ../../secrets/hermes.yaml;
    defaultSopsFormat = "yaml";
  };
}
