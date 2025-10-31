{
  config,
  pkgs,
  lib,
  modulesPath,
  options,
  ukiPath,
  espSize,
  ...
}: let
  inherit (config.image.repart.verityStore) partitionIds;
in {
  imports = [
    "${toString modulesPath}/image/repart.nix"
  ];

  ec2.efi = true;

  fileSystems = {
    "/" = {
      fsType = "tmpfs";
      options = ["mode=0755"];
    };

    "/usr" = {
      device = "/dev/mapper/usr";
      # explicitly mount it read-only otherwise systemd-remount-fs will fail
      options = ["ro"];
      fsType = config.image.repart.partitions.${partitionIds.store}.repartConfig.Format;
    };

    # bind-mount the store
    "/nix/store" = {
      device = "/usr/nix/store";
      options = ["bind"];
    };
  };

  image.repart = {
    verityStore = {
      enable = true;
      # by default the module works with systemd-boot, for simplicity this test directly boots the UKI
      inherit ukiPath;
    };

    sectorSize = 512;

    partitions = {
      ${partitionIds.esp} = {
        # the UKI is injected into this partition by the verityStore module
        repartConfig = {
          Type = "esp";
          Format = "vfat";
          SizeMinBytes = espSize;
        };
      };
      ${partitionIds.store-verity}.repartConfig = {
        Minimize = "best";
      };
      ${partitionIds.store}.repartConfig = {
        Minimize = "best";
      };
    };
  };

  boot = {
    loader.grub.enable = false;
    initrd.systemd.enable = true;
    initrd.systemd.dmVerity.enable = true;
    uki = {
      name = "nixattestedami";
      version = config.system.image.version;
      tries = 3; # Enable automatic boot assessment
    };
  };

  # don't create /usr/bin/env
  # this would require some extra work on read-only /usr
  # and it is not a strict necessity
  system.activationScripts.usrbinenv = lib.mkForce "";

  boot.kernelParams = lib.mkAfter [
    "systemd.verity=1"
    "systemd.verity_root_options=panic-on-corruption"
  ];

  formatAttr = lib.mkForce "finalImage";
  fileExtension = lib.mkForce ".raw";
}
