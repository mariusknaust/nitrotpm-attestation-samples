{
  config,
  pkgs,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    "${toString modulesPath}/profiles/minimal.nix"
    "${toString modulesPath}/profiles/qemu-guest.nix"
    "${toString modulesPath}/profiles/hardened.nix"
  ];

  # The scudo allocator from hardened profile does not build, reset it to libc
  environment.memoryAllocator.provider = "libc";

  # Erofs is required, which is excluded by the hardened profile
  boot.blacklistedKernelModules = lib.mkForce (
    let
      hardenedModule = import "${toString modulesPath}/profiles/hardened.nix" {
        inherit config pkgs lib modulesPath;
      };
    in
    lib.remove "erofs" hardenedModule.config.content.boot.blacklistedKernelModules
  );

  system.image = {
    id = lib.mkDefault "nixos-tee";
    version = "1";
  };

  boot.enableContainers = lib.mkDefault false;
  boot.initrd.systemd.enable = lib.mkDefault true;

  boot.kernelParams = lib.mkAfter [
    "panic=30"
    "boot.panic_on_fail" # reboot the machine upon fatal boot issues
    "lockdown=1"
    "console=ttyS0,115200n8"
    "console=tty0"
    "random.trust_cpu=on"
    "tpm_crb.force=1"
    "systemd.gpt_auto=0" # Disable systemd-gpt-auto-generator to prevent e.g. ESP mounting
  ];

  documentation.info.enable = lib.mkDefault false;

  networking.useNetworkd = lib.mkDefault true;
  networking.firewall.enable = lib.mkDefault true;

  nix.enable = false;

  programs.command-not-found.enable = lib.mkDefault false;
  programs.less.lessopen = lib.mkDefault null;

    # Secure network defaults
  systemd.network = {
    enable = lib.mkDefault true;
    networks."10-secure" = {
      matchConfig.Name = lib.mkDefault "*";
      networkConfig = {
        DHCP = lib.mkDefault "ipv4";
        IPv6AcceptRA = lib.mkDefault false;
        LinkLocalAddressing = lib.mkDefault "no";
        LLMNR = lib.mkDefault false;
        MulticastDNS = lib.mkDefault false;
        DNSOverTLS = lib.mkDefault "opportunistic";
        DNSSEC = lib.mkDefault "allow-downgrade";
      };
    };
  };

  # Disable auto-login
  services.getty.autologinUser = lib.mkForce null;
  services.sshd.enable = lib.mkForce false;
  services.udisks2.enable = false; # udisks has become too bloated to have in a headless system

  system.disableInstallerTools = lib.mkDefault true;
  system.switch.enable = lib.mkDefault false;

  users.mutableUsers = false;
  # Remove root password
  users.users.root.hashedPassword = lib.mkForce null;
  # Disable checking that at least the `root` user or a user in the `wheel` group can log in using a password or an SSH key
  users.allowNoPasswordLogin = lib.mkForce true;
}
