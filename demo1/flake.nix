{
  description = "Demo flake for showcasing and using demo packages meaningfully";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    automatorFlake.url = "path:../";  # Adjust the path as necessary
  };

  outputs = { self, automatorFlake, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      autoPackage = automatorFlake.legacyPackages.${system}.packageGenerator {
          url = "https://github.com/OpenTTD/nml";
          version = "0.7.6";
          hash = "sha256-jAvzfmv8iLs4jb/rzRswiAPHZpx20hjfbG/NY4HGcF0=";
          option = 2;
        };
      autoPackage1 =  automatorFlake.legacyPackages.${system}.packageGenerator {
          url = "https://github.com/cfoust/cy";
          rev = "77ea96a";
          version = "v1.5.1";
          hash = "sha256-lRBggQqi5F667w2wkMrbmTZu7DX/wHD5a4UIwm1s6V4=";
          vendorHash = null;
          option = 3;
          extraArgs = with pkgs; {
            buildInputs = [ "xorg.libX11" ];
            doCheck = false;
          };
        };

    in
    {
      legacyPackages.${system} = {       
        packagesFile = pkgs.writeTextFile {
          name = "flake-nix";
          destination = "/flake.nix";
          text = autoPackage;
        };
        packagesFile1 = pkgs.writeTextFile {
          name = "flake-nix";
          destination = "/flake.nix";
          text = autoPackage1;
        };
      };
    };
}
