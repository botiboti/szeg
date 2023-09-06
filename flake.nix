{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    crane.url = "github:ipetkov/crane";
    crane.inputs.nixpkgs.follows = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    mkElmDerivation.url = "github:jeslie0/mkElmDerivation";
  };
  outputs = { self, nixpkgs, crane, flake-utils, mkElmDerivation }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          overlays = [ mkElmDerivation.overlays.mkElmDerivation ];
          inherit system;
        };
        craneLib = crane.lib.${system};
        watch = pkgs.writeShellApplication {
          name = "watch";
          runtimeInputs = self.packages.${system}.szeg.nativeBuildInputs;
          text = ''
            cargo run #watch -x run
          '';
        };
      in with pkgs; {
        packages = {
          default = self.packages.${system}.szeg;
          szeg = craneLib.buildPackage {
            src = craneLib.cleanCargoSource (craneLib.path ./.);

            # Add extra inputs here or any other derivation settings
            # doCheck = true;
            # buildInputs = [];
            # nativeBuildInputs = [];
          };
          szeg-model = pkgs.runCommandNoCC "szeg-model" { } ''
            mkdir -p $out/gen
            ${self.packages.${system}.szeg}/bin/szeg-model > $out/gen/Model.elm
          '';
          szeg-frontend = pkgs.mkElmDerivation {
            name = "szeg-frontend";
            version = "0.1.0";
            targets = [ ./src/Main.elm ];
            src = ./.;
            outputHtml = true;
            preConfigure = ''
              mkdir gen
              cp ${self.packages.${system}.szeg-model}/gen/* gen/
            '';
            optimizationLevel = 2;
          };
        };
        devShells.default = mkShell {
          inputsFrom = [ self.packages.${system}.szeg ];
          buildInputs = [ pkgs.elmPackages.elm ];
          shellHook = ''
            set -a
            mkdir -p gen
            cp ${self.packages.${system}.szeg-model}/gen/* gen/
          '';
        };
        devShells.terraform = mkShell {
          buildInputs = with pkgs; [ terraform tflint terraform-docs ];
          shellHook = ''
            set -a
            source ./creds.env
            set +a
          '';
        };
        apps = {
          default = self.apps.${system}.szeg;
          szeg = {
            type = "app";
            program = "${self.packages.${system}.szeg}/bin/szeg";
          };
          watch = {
            type = "app";
            program = "${watch}/bin/watch";
          };
        };
      });
}
