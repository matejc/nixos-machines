{ pkgs ? import <nixpkgs> {} }:
let
  jellyfin-sdk = import ./jellyfin-sdk.nix { inherit pkgs; };
  python = pkgs.python3.withPackages (pythonPackages: [
    jellyfin-sdk
  ]);
in {
  build = pkgs.runCommand "python-jellyfin-filter-run" {
    buildInputs = [ python pkgs.ffmpeg ];
  } ''
    echo "#!${pkgs.stdenv.shell}" > $out
    echo "export JELLYFIN_FFMPEG=${pkgs.ffmpeg}/bin/ffmpeg" >> $out
    echo "${python}/bin/python ${./filter.py}" >> $out
    chmod +x $out
  '';
  shell = pkgs.mkShell {
    packages = [ python pkgs.basedpyright pkgs.ffmpeg ];
    shellHook = ''
      echo "Jellyfin+Python shell"
    '';
  };
}
