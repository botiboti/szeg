{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    crane.url = "github:ipetkov/crane";
    crane.inputs.nixpkgs.follows = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, crane, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        craneLib = crane.lib.${system};
        watch = pkgs.writeShellApplication {
          name = "watch";
          runtimeInputs = self.packages.${system}.rust_proj.nativeBuildInputs;
          text = ''
            cargo run #watch -x run
          '';
        };
      in with pkgs; {
        packages = {
          default = self.packages.${system}.rust_proj;
          rust_proj = craneLib.buildPackage {
            src = craneLib.cleanCargoSource (craneLib.path ./.);

            # Add extra inputs here or any other derivation settings
            # doCheck = true;
            # buildInputs = [];
            # nativeBuildInputs = [];
          };
        };
        devShells.default =
          mkShell { inputsFrom = [ self.packages.${system}.rust_proj ]; };
        devShells.terraform = mkShell {
          buildInputs = with pkgs; [ terraform tflint terraform-docs ];
          shellHook = ''
            set -a
            source ./creds.env
            set +a
          '';
        };
        apps = {
          default = self.apps.${system}.rust_proj;
          rust_proj = {
            type = "app";
            program = "${self.packages.${system}.rust_proj}/bin/rust_proj";
          };
          watch = {
            type = "app";
            program = "${watch}/bin/watch";
          };
        };
      });
}
