{ config, nixpkgs, ... }:
{
  imports = [
    "${nixpkgs}/nixos/modules/virtualisation/google-compute-image.nix"
  ];
}
