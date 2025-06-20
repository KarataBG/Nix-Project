{
  description = "Demo flake for showcasing and using demo packages meaningfully";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    automatorFlake.url = "path:../";
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

      autoPackage3 = automatorFlake.legacyPackages.${system}.packageGenerator {
        url = "https://github.com/OpenTTD/nml";
        version = "0.7.6";
        hash = "sha256-jAvzfmv8iLs4jb/rzRswiAPHZpx20hjfbG/NY4HGcF0=";
        option = 1;
      };
      autoPackage4 = automatorFlake.legacyPackages.${system}.packageGenerator {
        url = "https://github.com/OpenTTD/nml";
        version = "0.7.6";
        hash = "sha256-jAvzfmv8iLs4jb/rzRswiAPHZpx20hjfbG/NY4HGcF0=";
        option = 4;
      };

    in
    {
      legacyPackages.${system} = {

        
        #User generated flake
        textFile = autoPackage; #Text version
        packagesFile = pkgs.writeTextFile { #File creation version
          name = "flake-nix";
          destination = "/automatic/flake.nix";
          text = autoPackage;
        };

        #Second user generated flake
        textFile1 = autoPackage1; #Text version
        packagesFile1 = pkgs.writeTextFile { #File creation version
          name = "flake-nix";
          destination = "/automatic/flake.nix";
          text = autoPackage1;
        };

        #Text version callPackage
        callPackage1 = automatorFlake.legacyPackages.${system}.callPackage1.packageCallString;
        #Code version callPackage
        callPackage2 = pkgs.callPackage automatorFlake.legacyPackages.${system}.callPackage2.packageCall {};

        #User build package nix-2
        nml = autoPackage3;
        #User build package nix-2 string
        nmlString = autoPackage4;
        


        
      };
    };
}
