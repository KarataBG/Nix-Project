{

  description = "Flake wrapping GitHub packages with options";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      inherit (nixpkgs) lib;

      # Parse GitHub URL for extracting owner/repo information
      parseGitHubUrl = url:
        let
          parts = lib.strings.splitString "/" url;
          websiteSource = builtins.elemAt parts 2;
          owner = builtins.elemAt parts 3;
          repo = builtins.elemAt parts 4;
        in {
          websiteSource = websiteSource;
          owner = owner;
          repo = repo;
        };

      URLParser = { url, rev ? "", version ? "1.0.0", hash, }:
        let
          parsed = parseGitHubUrl url;

          owner = parsed.owner;
          repo = parsed.repo;
          websiteSource = parsed.websiteSource;

          fetchGitHub = pkgs.fetchFromGitHub {
            inherit owner repo hash;
            tag = version;
          };

          fetchGitLab =
            pkgs.fetchFromGitLab { inherit owner repo hash rev version; };

          fetchGitiles =
            pkgs.fetchFromGitiles { inherit url hash rev version; };

          fetchCrate = pkgs.fetchCrate {
            pname = repo;
            inherit hash version;
          };
        in if websiteSource == "github.com" then {
          drv = fetchGitHub;
          srcString = ''
            pkgs.fetchFromGitHub {
              repo = "${repo}";
              owner = "${owner}";
              tag = "${version}";
              hash = "${hash}";
            };
          '';
        } else if websiteSource == "gitlab.com" then {
          drv = fetchGitLab;
          srcString = ''
            pkgs.fetchFromGitLab {
              repo = "${repo}";
              owner = "${owner}";
              tag = "${version}";
              version = "${version}";
            };
          '';
        } else if websiteSource == "chromium.googlesource.com" then {
          drv = fetchGitiles;
          srcString = ''
            pkgs.fetchFromGitiles {
              url = "${url}";
              hash = "${hash}";
              rev = "${rev}";
              hash = "${hash}";
            };
          '';
        } else if websiteSource == "crates.io" then {
          drv = fetchCrate;
          srcString = ''
            pkgs.fetchCrate {
              pname = "${repo}";
              hash = "${hash}";
              version = "${version}";
            };
          '';
        } else
          throw "Unsuported website";

      # Generate the package based on input parameters
      generatePackage = { url, rev ? "", version ? "1.0.0", option ? 1
        , hash ? lib.trace "Use the generated hash as input" lib.fakeHash
        , vendorHash ?
          pkgs.lib.trace "Use the generated vendorHash as input" lib.fakeHash
        , extraArgs ? { } }:
        let

          urlParser = URLParser {
            url = url;
            rev = rev;
            version = version;
            hash = hash;
          };

          src = urlParser.drv;
          srcString = urlParser.srcString;

          repo = (parseGitHubUrl url).repo;
          name = "${repo}-automated-package";

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
            in { lockFileContents = fixupLockFile "${src}/Cargo.lock"; }
          else
            null;

          resolvePackage = name:
            let
              parts = lib.splitString "." name;
              # uses getArrr getting the derivation of the library head
              # example xorg.libX11 gets xorg and gets the derivation of xorg from nixpkgs
              # iterates over the parts adding them all subParts to the head getting the derivation each time 
              packageHead = builtins.getAttr (builtins.head parts) pkgs;
              packageTail = builtins.tail parts;
              resolvedPackage = builtins.foldl' (pkg: part:
                if builtins.hasAttr part pkg then
                  pkg.${part}
                else
                  throw "Package '${name}' not found in pkgs.") packageHead
                packageTail;
            in resolvedPackage;

        in if option == 1 then
        # Option 1: direct application build standard nix-2 packet
          if isPython then
            if isPyProject then
              pkgs.python3Packages.buildPythonApplication (rec {
                inherit src name version;
                pyproject = true;
                dependencies = with pkgs.python3Packages; [
                  setuptools
                  ply
                  pillow
                ];
              } // extraArgs)
            else
              pkgs.python3Packages.buildPythonApplication rec {
                inherit src name version;
                dependencies = with pkgs.python3Packages; [
                  setuptools
                  ply
                  pillow
                ];
              }
          else if isGo then

            pkgs.buildGoModule rec {
              inherit src name version vendorHash;

              # modRoot = "";
              modRoot = if builtins.hasAttr "modRoot" extraArgs then
                extraArgs.modRoot
              else
                "";

              buildInputs = if builtins.hasAttr "buildInputs" extraArgs then
                map resolvePackage extraArgs.buildInputs
              else
                [ ];

              doCheck = if builtins.hasAttr "doCheck" extraArgs then
                extraArgs.doCheck
              else
                true;

            }
          else if isRust then
            pkgs.rustPlatform.buildRustPackage rec {
              inherit src name version;
              cargoLock = rustCargoLock;
            }
          else
            throw
            "Unknown language or missing necessary build files. Please check your source structure."

        else if option == 2 then
        # Option 2: returns a flake with the package
         generateFlake package srcString
        else if option == 3 then
        # Defines package for callPackage {}
          let
            packageFile = pkgs.stdenv.mkDerivation rec {
              inherit (package) name version src meta;
            };
          in packageFile

        else
          throw "Invalid option. Please choose 1, 2, or 3.";
      
      generateFlake = {package, srcString}:
          let
            inherit (package) name version src;
            packageFlake = {
              description = "A flake containing the package";

              inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

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

            packageFlakeString = # nix #
              ''
              description = "A flake containing the package";
              inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

              outputs =
                { self, nixpkgs }:
                let
                  system = "x86_64-linux";
                  pkgs = import nixpkgs { inherit system; };
                in
                {
                  packages.${system}.default = {
                    # inherit name version src;
                    name = ${name};
                    src = ${srcString};
                  };
                };                      
              '';
          in packageFlake packageFlakeString;

    in {
      inherit pkgs;
      inherit (generateFlake) packageFlakeString;
      # inherit (generateFlake) packageFlakeString;

      # legacyPackages.${system}.generatedFlake = packageFlakeString;

      templates.rust = {
        path = ./rust;
        description = "A simple Rust/Cargo project";
        welcomeText = ''
          # Simple Rust/Cargo Template
          ## Intended usage
          The intended usage of this flake is to create a new Rust project.

          ## More info
          - [Rust language](https://www.rust-lang.org/)
          - [Rust on the NixOS Wiki](https://wiki.nixos.org/wiki/Rust)
        '';
      };

      #python
      packages.${system} = {
        examplePackage1 = generatePackage {
          url = "https://github.com/OpenTTD/nml";
          # rev = "5295c19";
          # version = "0.7.6";
          hash = "sha256-jAvzfmv8iLs4jb/rzRswiAPHZpx20hjfbG/NY4HGcF0=";
          option = 1; # options - 1 2 3
        };

        #rust
        examplePackage2 = generatePackage {
          url = "https://github.com/evmar/n2";
          # rev = "5295c19";
          # version = "0.7.6";
          hash = "sha256-eWcN/iK/ToufABi4+hIyWetp2I94Vy4INHb4r6fw+TY=";
          option = 1; # options - 1 2 3
        };
        examplePackage5 = generatePackage {
          url = "https://gitlab.com/kornelski/mandown";
          rev = "9da94876";
          # version = "v1.1.0";
          hash = "sha256-wEv7h3Kl4EczmsY4FuGOvRgeGf0rgANhONhCKyu6zik=";
          option = 1; # options - 1 2 3
        };
        examplePackage6 = generatePackage {
          url = "https://crates.io/crates/petname";
          # rev = "9da94876";
          version = "3.0.0-alpha.2";
          hash = "sha256-6gJkaHAhau2HKKwVa/FL1mZfC9IJkyORm5P8MzLnQ5Q=";
          option = 1; # options - 1 2 3
        };

        #go
        examplePackage3 = generatePackage {
          url = "https://github.com/lestrrat-go/jwx";
          rev = "a68b08e";
          version = "v3.0.6";
          hash = "sha256-D3HhkAEW1vxeq6bQhRLe9+i/0u6CUhR6azWwIpudhBI=";
          vendorHash = "sha256-FjNUcNI3A97ngPZBWW+6qL0eCTd10KUGl/AzByXSZt8=";
          # vendorHash = "sha256-JXH8wqf3CuqOB2t+tcM8pY7nS4LTpGWdgnJdaYYkXwU=";
          option = 1; # options - 1 2 3
          extraArgs = { modRoot = "cmd/jwx"; };
        };
        examplePackage4 = generatePackage {
          url = "https://github.com/cfoust/cy";
          rev = "77ea96a";
          version = "v1.5.1";
          hash = "sha256-lRBggQqi5F667w2wkMrbmTZu7DX/wHD5a4UIwm1s6V4=";
          vendorHash = null;
          option = 1; # options - 1 2 3
          # extraArgs = with pkgs; { buildInputs = [ pkgs.xorg.libX11 ]; };
          extraArgs = with pkgs; {
            buildInputs = [ "xorg.libX11" ];
            doCheck = false;
          };
        };

      };

    };
}

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
# sha256-lRBggQqi5F667w2wkMrbmTZu7DX/wHD5a4UIwm1s6V4=
# cy
# sha256-D3HhkAEW1vxeq6bQhRLe9+i/0u6CUhR6azWwIpudhBI=
# vendorHash = "sha256-FjNUcNI3A97ngPZBWW+6qL0eCTd10KUGl/AzByXSZt8=";
# jwx
