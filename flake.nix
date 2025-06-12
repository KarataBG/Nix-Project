{
  description = "Flake wrapping GitHub packages with options";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

  outputs = { self, nixpkgs }: 
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      # Parse GitHub URL for extracting owner/repo information
      parseGitHubUrl = url: let
        parts = pkgs.lib.strings.splitString "/" url;
        websiteSource = builtins.elemAt parts 2;
        owner = builtins.elemAt parts 3;
        repo = builtins.elemAt parts 4;
      in
        { websiteSource = websiteSource; owner = owner; repo = repo; };

      # Generate the package based on input parameters          
      # naprawi prowerkata koi ezik e

      generatePackage = { url, rev, tag, option, hash }: let
        parsed = parseGitHubUrl url;

        owner = parsed.owner;
        repo = parsed.repo;

        name = "${repo}-automated-package";
        version = tag;

        src = pkgs.fetchFromGitHub {
          inherit owner repo;
          rev = tag;
          hash = hash;
        };
        package = {
          inherit name version src;
          meta = {
            description = "An automatic package";
            license = "MIT";
          };
        };
      in
        if option == 1 then
          # Option 1: direct python application build standard nix-2 packet
          pkgs.python3Packages.buildPythonApplication {
            inherit (package) name version src meta;
            pyproject = true;
            dependencies = with pkgs.python3Packages; [
              setuptools ply pillow
            ];
          }
        else if option == 2 then
          # Option 2: returns a flake with the package
          let
            packageFlake = {
              description = "A flake containing the package";

              inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

              outputs = { self, nixpkgs }: 
                let
                  system = "x86_64-linux";
                  pkgs = import nixpkgs { inherit system; };
                in {
                  packages.${system}.default = {
                    inherit name version src;
                    meta = {
                      description = package.meta.description;
                      license = package.meta.license;
                    };
                  };
                };
            };
          in
            packageFlake
        else if option == 3 then
          # Defines package for callPackage {}
          let
            packageFile = pkgs.stdenv.mkDerivation rec{
            inherit (package) name version src meta;
          };
          in
           packageFile

          # {
          #   inherit (pkgs) fetchFromGitHub;
          #   inherit (package) name version src;
          # }

        else
          throw "Invalid option. Please choose 1, 2, or 3.";

    in {
      packages.${system}.examplePackage1 = generatePackage {
        url = "https://github.com/LoLei/razer-cli";
        rev = "4b979a4";
        tag = "0.7.6";
        hash = "sha256-jjCMxY0PEar9F4O4vu5niU2U74rxoaBczqW5CKLEKvk=";
        option = 1;  # options - 1 2 3
      };
    };
}



# sha256-uwTqDCYmG/5dyse0tF/CPG+9SlThyRyeHJ0OSBpcQio=
# razer

# sha256-jAvzfmv8iLs4jb/rzRswiAPHZpx20hjfbG/NY4HGcF0= 
# nmlc

# sha256-jjCMxY0PEar9F4O4vu5niU2U74rxoaBczqW5CKLEKvk=
# razer