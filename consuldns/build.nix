{ pkgs ? import <nixpkgs> {} } :
pkgs.stdenv.mkDerivation {
  name = "consuldns";
  src = ./.;
  buildInputs = [
    pkgs.rustc
    pkgs.cargo
  ];
  buildPhase = ''
    export CARGO_HOME=$(pwd)/cargo_home
    cargo build --release
  '';
  installPhase = ''
    mkdir -p $out/bin
    cp target/release/consuldns $out/bin/
  '';
}