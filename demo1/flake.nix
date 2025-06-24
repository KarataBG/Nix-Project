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
          option = 3; # options - 1 2 3
        };
      autoPackage3 = automatorFlake.legacyPackages.${system}.packageGenerator {
          url = "https://github.com/cfoust/cy";
          rev = "77ea96a";
          version = "v1.5.1";
          hash = "sha256-lRBggQqi5F667w2wkMrbmTZu7DX/wHD5a4UIwm1s6V4=";
          vendorHash = null;
          option = 3; # options - 1 2 3
          extraArgs = {
            buildInputs = [ "xorg.libX11" ];
            doCheck = false;
          };
        };
      autoPackage4 = automatorFlake.legacyPackages.${system}.packageGenerator {
        url = "https://github.com/evmar/n2";
        hash = "sha256-eWcN/iK/ToufABi4+hIyWetp2I94Vy4INHb4r6fw+TY=";
        option = 3; # options - 1 2 3
        extraArgs = with pkgs; {doCheck = false; };
      };




      #autos for nix-2
      autoPackage5 = automatorFlake.legacyPackages.${system}.packageGenerator {
        url = "https://codeberg.org/svartstare/pass2csv/";
          version = "v1.2.0";
          hash = "sha256-AzhKSfuwIcw/iizizuemht46x8mKyBFYjfRv9Qczr6s=";
          option = 1; # options - 1 2 3
          extraArgs = with pkgs; { };
      };
      autoPackage6 = automatorFlake.legacyPackages.${system}.packageGenerator {
        url = "https://codeberg.org/svartstare/pass2csv/";
          version = "v1.2.0";
          hash = "sha256-AzhKSfuwIcw/iizizuemht46x8mKyBFYjfRv9Qczr6s=";
          option = 1; # options - 1 2 3
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
        pass2 = autoPackage5.nixCall;
        #User build package nix-2 string
        pass2String = autoPackage6.nixCallString;
        
        generatedFlake1 = automatorFlake.legacyPackages.${system}.packageGenerator  {
          url = "https://github.com/cfoust/cy";
          rev = "77ea96a";
          version = "v1.5.1";
          hash = "sha256-lRBggQqi5F667w2wkMrbmTZu7DX/wHD5a4UIwm1s6V4=";
          vendorHash = null;
          option = 2; # options - 1 2 3
          extraArgs = {
            buildInputs = [ "xorg.libX11" ];
            doCheck = false;
          };
        };
        generatedFlake2 = automatorFlake.legacyPackages.${system}.packageGenerator  {
          url = "https://github.com/lestrrat-go/jwx";
          version = "v3.0.6";
          hash = "sha256-D3HhkAEW1vxeq6bQhRLe9+i/0u6CUhR6azWwIpudhBI=";
          vendorHash = "sha256-FjNUcNI3A97ngPZBWW+6qL0eCTd10KUGl/AzByXSZt8=";
          option = 2; # options - 1 2 3
          extraArgs = { modRoot = "cmd/jwx"; };
        };
        generatedFlake3 = automatorFlake.legacyPackages.${system}.packageGenerator  {
          url = "https://github.com/OpenTTD/nml";
          version = "0.7.6";
          hash = "sha256-jAvzfmv8iLs4jb/rzRswiAPHZpx20hjfbG/NY4HGcF0=";
          option = 2; # options - 1 2 3
        };
        generatedFlake4 = automatorFlake.legacyPackages.${system}.packageGenerator  {
          url = "https://github.com/evmar/n2";
          hash = "sha256-eWcN/iK/ToufABi4+hIyWetp2I94Vy4INHb4r6fw+TY=";
          option = 2; # options - 1 2 3
          extraArgs = {
            doCheck = false;
          };
        };
        callPackage9 = automatorFlake.legacyPackages.${system}.packageGenerator  {
          url = "https://github.com/cfoust/cy";
          rev = "77ea96a";
          version = "v1.5.1";
          hash = "sha256-lRBggQqi5F667w2wkMrbmTZu7DX/wHD5a4UIwm1s6V4=";
          vendorHash = null;
          option = 3; # options - 1 2 3
          extraArgs = with pkgs; {
            buildInputs = [ "xorg.libX11" ];
            doCheck = false;
          };
        };
        callPackage10 = automatorFlake.legacyPackages.${system}.packageGenerator {
          url = "https://crates.io/crates/petname";
          version = "3.0.0-alpha.2";
          hash = "sha256-6gJkaHAhau2HKKwVa/FL1mZfC9IJkyORm5P8MzLnQ5Q=";
          option = 3; # options - 1 2 3
        };
        nixPackage1 = automatorFlake.legacyPackages.${system}.packageGenerator  {
          url = "https://github.com/cfoust/cy";
          rev = "77ea96a";
          version = "v1.5.1";
          hash = "sha256-lRBggQqi5F667w2wkMrbmTZu7DX/wHD5a4UIwm1s6V4=";
          vendorHash = null;
          option = 1; # options - 1 2 3
          extraArgs = with pkgs; {
            buildInputs = [ "xorg.libX11" ];
            doCheck = false;
          };
        };
        nixPackage2 = automatorFlake.legacyPackages.${system}.packageGenerator  {
          url = "https://github.com/LoLei/razer-cli";
          version = "2.3.0";
          hash = "sha256-uwTqDCYmG/5dyse0tF/CPG+9SlThyRyeHJ0OSBpcQio=";
          option = 1; # options - 1 2 3
          extraArgs = with pkgs; { };
        };
        nixPackage3 = automatorFlake.legacyPackages.${system}.packageGenerator  {
          url = "https://codeberg.org/svartstare/pass2csv/";
          version = "v1.2.0";
          hash = "sha256-AzhKSfuwIcw/iizizuemht46x8mKyBFYjfRv9Qczr6s=";
          option = 1; # options - 1 2 3
          extraArgs = with pkgs; { };
        };

        demoPackage1 =  automatorFlake.legacyPackages.${system}.packageGenerator  {
          url = "https://github.com/cfoust/cy";
          rev = "77ea96a";
          version = "v1.5.1";
          hash = "sha256-lRBggQqi5F667w2wkMrbmTZu7DX/wHD5a4UIwm1s6V4=";
          vendorHash = null;
          option = 1; # options - 1 2 3
          extraArgs = with pkgs; {
            buildInputs = [ "xorg.libX11" ];
            doCheck = false;
          };
        };
        demoPackage2 =  automatorFlake.legacyPackages.${system}.packageGenerator  {
          url = "https://github.com/OpenTTD/nml";
          version = "0.7.6";
          hash = "sha256-jAvzfmv8iLs4jb/rzRswiAPHZpx20hjfbG/NY4HGcF0=";
          option = 2; # options - 1 2 3
        };
        demoPackage3 =  automatorFlake.legacyPackages.${system}.packageGenerator  {
          url = "https://github.com/lestrrat-go/jwx";
          version = "v3.0.7";
          hash = "sha256-vR7QsRAVdYmi7wYGsjuQiB1mABq5jx7mIRFiduJRReA=";
          vendorHash = "sha256-fpjkaGkJUi4jrdFvrClx42FF9HwzNW5js3I5HNZChOU=";
          option = 3; # options - 1 2 3
          extraArgs = { modRoot = "cmd/jwx"; };
        };
        
        demoPackage4 =  automatorFlake.legacyPackages.${system}.packageGenerator  {
          url = "https://github.com/cfoust/cy";
          rev = "77ea96a";
          version = "v1.5.1";
          hash = "sha256-lRBggQqi5F667w2wkMrbmTZu7DX/wHD5a4UIwm1s6V4=";
          vendorHash = null;
          option = 1; # options - 1 2 3
          extraArgs = with pkgs; {
            buildInputs = [ "xorg.libX11" ];
            doCheck = false;
          };
        };
      };

      packages.${system} = {
        #python
        examplePackage1 = automatorFlake.legacyPackages.${system}.packageGenerator {
          url = "https://github.com/OpenTTD/nml";
          version = "0.7.6";
          hash = "sha256-jAvzfmv8iLs4jb/rzRswiAPHZpx20hjfbG/NY4HGcF0=";
          option = 1; # options - 1 2 3
        };
        examplePackage2 = automatorFlake.legacyPackages.${system}.packageGenerator {
          url = "https://github.com/OpenTTD/nml";
          version = "0.7.6";
          hash = "sha256-jAvzfmv8iLs4jb/rzRswiAPHZpx20hjfbG/NY4HGcF0=";
          option = 1; # options - 1 2 3
        };
        examplePackage3 = automatorFlake.legacyPackages.${system}.packageGenerator {
          url = "https://codeberg.org/svartstare/pass2csv/";
          version = "v1.2.0";
          hash = "sha256-AzhKSfuwIcw/iizizuemht46x8mKyBFYjfRv9Qczr6s=";
          option = 1; # options - 1 2 3
          extraArgs = with pkgs; { };
        };

        #rust
        examplePackage4 = automatorFlake.legacyPackages.${system}.packageGenerator {
          url = "https://github.com/evmar/n2";
          hash = "sha256-eWcN/iK/ToufABi4+hIyWetp2I94Vy4INHb4r6fw+TY=";
          rev = "d67d508c389ac2e6961c6f84cd668f05ec7dc7b7";
          extraArgs = {
            doCheck = false;
          };
          option = 1; # options - 1 2 3
        };
        examplePackage5 = automatorFlake.legacyPackages.${system}.packageGenerator {
          url = "https://gitlab.com/kornelski/mandown";
          rev = "9da94876";
          hash = "sha256-wEv7h3Kl4EczmsY4FuGOvRgeGf0rgANhONhCKyu6zik=";
          option = 1; # options - 1 2 3
        };
        examplePackage6 = automatorFlake.legacyPackages.${system}.packageGenerator {
          url = "https://crates.io/crates/petname";
          version = "3.0.0-alpha.2";
          hash = "sha256-6gJkaHAhau2HKKwVa/FL1mZfC9IJkyORm5P8MzLnQ5Q=";
          option = 1; # options - 1 2 3
        };

        #go
        examplePackage7 = automatorFlake.legacyPackages.${system}.packageGenerator {
          url = "https://github.com/lestrrat-go/jwx";
          version = "v3.0.7";
          hash = "sha256-vR7QsRAVdYmi7wYGsjuQiB1mABq5jx7mIRFiduJRReA=";
          vendorHash = "sha256-fpjkaGkJUi4jrdFvrClx42FF9HwzNW5js3I5HNZChOU=";
          option = 1; # options - 1 2 3
          extraArgs = { modRoot = "cmd/jwx"; };
        };
        examplePackage8 = automatorFlake.legacyPackages.${system}.packageGenerator {
          url = "https://github.com/cfoust/cy";
          rev = "77ea96a";
          version = "v1.5.1";
          hash = "sha256-lRBggQqi5F667w2wkMrbmTZu7DX/wHD5a4UIwm1s6V4=";
          vendorHash = null;
          option = 1; # options - 1 2 3
          extraArgs = with pkgs; {
            buildInputs = [ "xorg.libX11" ];
            doCheck = false;
          };
        };

      };
    };
}
