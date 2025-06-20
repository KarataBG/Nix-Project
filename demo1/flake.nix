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

      #autos for flakes
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
          option = 2;
          extraArgs = {
            buildInputs = [ "xorg.libX11" ];
            doCheck = false;
          };
        };
      
      #autos for callPackage
      autoPackage2 = automatorFlake.legacyPackages.${system}.packageGenerator {
          url = "https://gitlab.com/kornelski/mandown";
          rev = "9da94876";
          hash = "sha256-wEv7h3Kl4EczmsY4FuGOvRgeGf0rgANhONhCKyu6zik=";
          option = 3; # options - 1 2 3 4
        };
      autoPackage3 = automatorFlake.legacyPackages.${system}.packageGenerator {
          url = "https://github.com/cfoust/cy";
          rev = "77ea96a";
          version = "v1.5.1";
          hash = "sha256-lRBggQqi5F667w2wkMrbmTZu7DX/wHD5a4UIwm1s6V4=";
          vendorHash = null;
          option = 3; # options - 1 2 3 4
          extraArgs = {
            buildInputs = [ "xorg.libX11" ];
            doCheck = false;
          };
        };
      autoPackage4 = automatorFlake.legacyPackages.${system}.packageGenerator {
        url = "https://github.com/evmar/n2";
        hash = "sha256-eWcN/iK/ToufABi4+hIyWetp2I94Vy4INHb4r6fw+TY=";
        option = 3; # options - 1 2 3 4
        extraArgs = with pkgs; {doCheck = false; };
      };




      #autos for nix-2
      autoPackage5 = automatorFlake.legacyPackages.${system}.packageGenerator {
        url = "https://codeberg.org/svartstare/pass2csv/";
          version = "v1.2.0";
          hash = "sha256-AzhKSfuwIcw/iizizuemht46x8mKyBFYjfRv9Qczr6s=";
          option = 1; # options - 1 2 3 4
          extraArgs = with pkgs; { };
      };
      autoPackage6 = automatorFlake.legacyPackages.${system}.packageGenerator {
        url = "https://codeberg.org/svartstare/pass2csv/";
          version = "v1.2.0";
          hash = "sha256-AzhKSfuwIcw/iizizuemht46x8mKyBFYjfRv9Qczr6s=";
          option = 4; # options - 1 2 3 4
          extraArgs = with pkgs; {};
      };

    in
    {
      legacyPackages.${system} = {

        
        #User generated flake
        textFile = autoPackage.packageFlakeString; #Text version
        packagesFile = pkgs.writeTextFile { #File creation version
          name = "flake-nix";
          destination = "/automatic/flake.nix";
          text = autoPackage.packageFlakeString;
        };

        #Second user generated flake
        textFile1 = autoPackage1.packageFlake; #Code version
        packagesFile1 = autoPackage1.packageFlake; #Code version

        #Text version callPackage generated
        callPackage1 = autoPackage2.packageCallString;
        callPackage2 = autoPackage3.packageCallString;
        callPackage3 = autoPackage4.packageCallString;
        #Code version callPackage generated
        callPackage4 = pkgs.callPackage autoPackage2.packageCall {};
        callPackage5 = pkgs.callPackage autoPackage3.packageCall {};
        callPackage6 = pkgs.callPackage autoPackage4.packageCall {};


        #Text version callPackage
        callPackage7 = automatorFlake.legacyPackages.${system}.callPackage1.packageCallString;
        #Code version callPackage
        callPackage8 = pkgs.callPackage automatorFlake.legacyPackages.${system}.callPackage2.packageCall {};

        #User build package nix-2
        pass2 = autoPackage5;
        #User build package nix-2 string
        pass2String = autoPackage6;
        


        
      };
    };
}
