{ pkgs ? (import <nixpkgs> { }) }:

pkgs.llvmPackages_latest.stdenv.mkDerivation {
  name = "dev-shell";
  nativeBuildInputs = with pkgs; [ zls zig ];
  buildInputs = with pkgs; [  ];
  strictDeps = false;
}
