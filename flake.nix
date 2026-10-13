{
  description = "Nix package for Cloudflare's cf CLI, tracking the npm release feed";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default-linux";
  };

  outputs = { self, nixpkgs, systems }:
    let
      inherit (nixpkgs) lib;
      eachSystem = f: lib.genAttrs (import systems) f;
      overlay = final: prev: {
        cf = final.callPackage ./package.nix { };
      };
      pkgsFor = system: import nixpkgs { inherit system; overlays = [ overlay ]; };
    in
    {
      overlays.default = overlay;

      packages = eachSystem (system: rec {
        cf = (pkgsFor system).cf;
        default = cf;
      });

      apps = eachSystem (system: rec {
        cf = {
          type = "app";
          program = "${(pkgsFor system).cf}/bin/cf";
        };
        default = cf;
      });

      devShells = eachSystem (system: {
        default = (pkgsFor system).mkShell {
          packages = with (pkgsFor system); [ nixpkgs-fmt jq curl nodejs_22 prefetch-npm-deps ];
        };
      });
    };
}
