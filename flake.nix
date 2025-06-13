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
      generatePackage = { url, rev ? "", version ? "1.0.0", option ? 1, hash }: let
        parsed = parseGitHubUrl url;

        owner = parsed.owner;
        repo = parsed.repo;

        name = "${repo}-automated-package";
        inherit version;

        # computedHash = builtins.hashFile "sha256" (pkgs.fetchFromGitHub {
        #   inherit owner repo rev version;
        #   hash = hash;
        # });

        src = pkgs.fetchFromGitHub {
          inherit owner repo rev version hash;
          # hash = hash;
        };



        package = {
          inherit name version src;
          meta = {
            description = "An automatic package";
            license = "MIT";
          };
        };

        
          # Detect the language based on common files
          isPython = builtins.pathExists "${src}/setup.py"; 
          isPyProject = builtins.pathExists "${src}/pyproject.toml";
          isGo = builtins.pathExists "${src}/go.mod";
          isRust = builtins.pathExists "${src}/Cargo.toml";
          isCargoLock = builtins.pathExists "${src}/Cargo.lock";

          rustCargoLock = if isRust && isCargoLock then
          let fixupLockFile = path: (builtins.readFile path);
          in {lockFileContents = fixupLockFile "${src}/Cargo.lock";}
          else null;

           vendorHash = if isGo && builtins.pathExists "${src}/vendor" then
            builtins.hashFile "sha256" "${src}/vendor"
            else null;


      
      in     

        if option == 1 then
          # Option 1: direct application build standard nix-2 packet

          if isPython then
            if isPyProject then pkgs.python3Packages.buildPythonApplication rec {
              inherit src name version; 
              pyproject = true;
              dependencies = with pkgs.python3Packages; [
              setuptools ply pillow
            ];            
            }
            else pkgs.python3Packages.buildPythonApplication rec {
              inherit src name version; 
              dependencies = with pkgs.python3Packages; [
              setuptools ply pillow
            ];            
            }
          else if isGo then
            pkgs.buildGoModule rec { 
              inherit src name version; 
              vendorHash = vendorHash;

              }
          else if isRust then
            pkgs.rustPlatform.buildRustPackage rec{ 
              inherit src name version; 
              cargoLock = rustCargoLock;
            }
          else
            throw "Unknown language or missing necessary build files. Please check your source structure."

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

        else
          throw "Invalid option. Please choose 1, 2, or 3.";

    in {
      #python 
      packages.${system} = {
        examplePackage1 = generatePackage {
          url = "https://github.com/OpenTTD/nml";
          # rev = "5295c19";
          # version = "0.7.6";
          hash = "sha256-jAvzfmv8iLs4jb/rzRswiAPHZpx20hjfbG/NY4HGcF0=";
          # hash = "";
          option = 1;  # options - 1 2 3
        };

        #rust
        examplePackage2 = generatePackage {
          url = "https://github.com/evmar/n2";
          # rev = "5295c19";
          # version = "0.7.6";
          hash = "sha256-eWcN/iK/ToufABi4+hIyWetp2I94Vy4INHb4r6fw+TY=";
          # hash = "";
          option = 1;  # options - 1 2 3
        };

      #go
        examplePackage3 = generatePackage {
          url = "https://github.com/cfoust/cy";
          # rev = "5295c19";
          # version = "0.7.6";
          hash = "sha256-2qInkF5kUXKXlxyRpe3jZxxtfvkkIFly1m46UKzCjLs=";
          # hash = "";
          option = 1;  # options - 1 2 3
        };
      };
      # if rev and version are not given builds the latest

      # inherit (generatePackage) src isPython isPyProject isGo isRust computedHash;
    };
}

# samo hasha zawisi koe ste wzeme - naprawi se nmlc hash i link evmar i stana nmlc packet s ime evmar

#python
# sha256-uwTqDCYmG/5dyse0tF/CPG+9SlThyRyeHJ0OSBpcQio=
# razer 2.3.0
# sha256-jAvzfmv8iLs4jb/rzRswiAPHZpx20hjfbG/NY4HGcF0= 
# nmlc 0.7.6

#rust
# sha256-eWcN/iK/ToufABi4+hIyWetp2I94Vy4INHb4r6fw+TY=
# cargohash sha256-+nr9v2N6BIDv0f4K/J1K0vijeIkrolfeXvdBGDHqwVU=
# evmar

#go
# sha256-2qInkF5kUXKXlxyRpe3jZxxtfvkkIFly1m46UKzCjLs=
# cy
# vendorhash sha256-43Mi3vVvIvRRP3PGbKQlKewbQwpI7vD48GE0v6IpZ88=
# jwx