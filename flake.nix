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
        in { inherit websiteSource owner repo; };

      URLParser = { url, rev ? "", version ? "1.0.0", hash, option }:
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

          fetchGitea = pkgs.fetchFromGitea {
            domain = "codeberg.org";
            tag = version;
            inherit owner repo hash;
          };

        in if websiteSource == "github.com" then {
          drv = fetchGitHub;
          srcString = ''
            ${if option == 3 then "pkgs." else ""}fetchFromGitHub {
                repo = "${repo}";
                owner = "${owner}";
                tag = "${version}";
                hash = "${hash}";
              };
          '';
        } else if websiteSource == "gitlab.com" then {
          drv = fetchGitLab;
          srcString = ''
            ${if option == 3 then "pkgs." else ""}fetchFromGitLab {
                repo = "${repo}";
                owner = "${owner}";
                tag = "${version}";
                version = "${version}";
              };
          '';
        } else if websiteSource == "chromium.googlesource.com" then {
          drv = fetchGitiles;
          srcString = ''
            ${if option == 3 then "pkgs." else ""}fetchFromGitiles {
                url = "${websiteSource}";
                hash = "${hash}";
                rev = "${rev}";
                version = "${version}";
              };
          '';
        } else if websiteSource == "crates.io" then {
          drv = fetchCrate;
          srcString = ''
            ${if option == 3 then "pkgs." else ""}.fetchCrate {
                pname = "${repo}";
                hash = "${hash}";
                version = "${version}";
              };
          '';
        } else if websiteSource == "codeberg.org" then {
          drv = fetchGitea;
          srcString = ''
            ${if option == 3 then "pkgs." else ""}fetchFromGitea{
                domain = "${websiteSource}";
                tag = "${version}";
                owner = "${owner}";
                repo = "${repo}";
                hash = "${hash}";
              };
          '';
        } else
          throw "Unsuported website";

      # Generate the package based on input parameters
      generatePackage = { url, rev ? "", version ? "1.0.0", option ? 1
        , hash ? lib.trace "Generate hash for input with nix build" ""
        , vendorHash ?
          lib.trace "Generate vendorHash for input with nix build" ""
        , extraArgs ? { } }:
        let
          urlParser = URLParser {
            url = url;
            rev = rev;
            version = version;
            hash = hash;
            option = option;
          };

          src = urlParser.drv;
          srcString = urlParser.srcString;

          repo = (parseGitHubUrl url).repo;
          name = "${repo}-automated-package";

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

          extractDependencies = pkgs.writeText "extract-dependencies.py" ''
            import sys
            import os

            # Read the requirements.txt file
            requirements_file = "${src}/requirements.txt"
            if not os.path.exists(requirements_file):
              sys.exit(0)
            try:
                with open(requirements_file) as f:
                    lines = f.readlines()
                    # Filter out comments and empty lines, and extract package names
                    install_requires = []
                    for line in lines:
                        stripped_line = line.strip()
                        if stripped_line and not stripped_line.startswith('#'):
                            # Split at '==' and take the first part (package name)
                            package_name = stripped_line.split('==')[0].strip()
                            install_requires.append(package_name)
            except Exception as e:
                print(f"Error reading {requirements_file}: {e}")
                sys.exit(1)

            # Print the dependencies
            if install_requires:
                print("\n".join(install_requires))
            else:
                print("No dependencies found.")
          '';

          # Run the script to get dependencies
          commandedDependencies = pkgs.runCommand "get-dependencies" {
            inherit src;
            buildInputs = [
              pkgs.python3
              pkgs.python3Packages.setuptools
            ];
          } ''
            ${pkgs.python3}/bin/python3 ${extractDependencies} > $out
          '';

          # Convert the dependencies into a Nix list
          listedDependencies = (builtins.map (dep: pkgs.python3Packages.${dep})
            (lib.splitString "\n" (builtins.readFile commandedDependencies)));

          # Collective attr setting to reduce redundency
          extraArgsCombiSetter = ''
            ${if builtins.hasAttr "modRoot" extraArgs then
              if builtins.isString extraArgs.modRoot then ''modRoot = "${extraArgs.modRoot}";'' else throw "modRoot has to be string"
            else
              ""}
            ${
              if builtins.hasAttr "buildInputs" extraArgs then
                "buildInputs = with pkgs; [ ${
                  if (builtins.all (input: builtins.isString input)) extraArgs.buildInputs then 
                    builtins.concatStringsSep " " extraArgs.buildInputs 
                  else throw " Add the package name surrounded with \"\" "
                } ];"
              else
                ""
            } 
            ${if builtins.hasAttr "doCheck" extraArgs then
              if builtins.isBoolean extraArgs.doCheck then 
                if extraArgs.doCheck then
                  "doCheck = true;"
                else
                  "doCheck = false;"
              else throw "doCheck has to be Boolean"
            else
              ""}
          '';

          packageDRVandSTR = if isPython then {
            drv = pkgs.python3Packages.buildPythonApplication rec {
              inherit src name version;
              pyproject = isPyProject;

              modRoot = extraArgs.modRoot or "";
              buildInputs = extraArgs.buildInputs or [ ];
              doCheck = extraArgs.doCheck or true;

              dependencies = with pkgs.python3Packages; lib.debug.traceVal  [
                (lib.splitString "\n" (builtins.readFile commandedDependencies))
                setuptools
                ply
                pillow
              ];
            };

            str = ''
              ${
                if option == 3 then "pkgs." else ""
              }python3Packages.buildPythonApplication rec {
                  name = "${name}";
                  version = "${version}";
                  src = ${srcString}
                  dependencies = with pkgs.python3Packages; [
                    ${builtins.readFile commandedDependencies}
                    setuptools
                    ply
                    pillow
                  ];
                  ${if isPyProject then
                    "pyproject = true;"
                  else
                    "pyproject = false;"  
                    }
                  ${extraArgsCombiSetter}               
              }
            '';
          } else if isGo then {
            drv = pkgs.buildGoModule rec {
              inherit name version src vendorHash;

              modRoot = extraArgs.modRoot or "";
              buildInputs = lib.debug.traceVal extraArgs.buildInputs or [ ];
              doCheck = extraArgs.doCheck or true;

            };

            str = ''
              ${if option == 3 then "pkgs." else ""}buildGoModule rec {
                name = "${name}";
                version = "${version}";
                src = ${srcString}
                ${
                  if vendorHash == null then
                    "vendorHash = null;"
                  else
                    ''vendorHash = "${vendorHash}";''
                }
                ${extraArgsCombiSetter} 
              }
            '';
          }

          else if isRust then {
            drv = pkgs.rustPlatform.buildRustPackage rec {
              inherit src name version;

              modRoot = extraArgs.modRoot or "";
              buildInputs = extraArgs.buildInputs or [ ];
              doCheck = extraArgs.doCheck or true;

              cargoLock = rustCargoLock;
            };

            str = ''
              ${
                if option == 3 then "pkgs." else ""
              }rustPlatform.buildRustPackage rec {
                name = "${name}";
                version = "${version}";
                src = ${srcString}
                
                cargoLock.lockFile = "''${src}/Cargo.lock";
                ${extraArgsCombiSetter}             
                }
            '';
          } else
            throw
            "Unknown language or missing necessary build files. Please check your source structure.";

          # resolvePackage = name:
          #   let
          #     parts = lib.splitString "." name;
          #     # uses getArrr getting the derivation of the library head
          #     # example xorg.libX11 gets xorg and gets the derivation of xorg from nixpkgs
          #     # iterates over the parts adding them all subParts to the head getting the derivation each time 
          #     packageHead = builtins.getAttr (builtins.head parts) pkgs;
          #     packageTail = builtins.tail parts;
          #     resolvedPackage = builtins.foldl' (pkg: part:
          #       if builtins.hasAttr part pkg then
          #         pkg.${part}
          #       else
          #         throw "Package '${name}' not found in pkgs.") packageHead
          #       packageTail;
          #   in resolvedPackage;

        in if option == 1 then
        # Option 1: direct application build standard nix-2 packet
          packageDRVandSTR.drv

        else if option == 2 then
        # Option 2: returns a flake with the package
          generateFlake { inherit srcString packageDRVandSTR; }
        else if option == 3 then
        # Option 3: Defines package for callPackage {}
        ''
          { pkgs, lib }:
          ${packageDRVandSTR.str}
        ''
        else if option == 4 then 
        # Option 4: Defines nix-2 package 
        ''
          with import <nixpkgs> {};
          ${packageDRVandSTR.str}
        '' 
        else throw "Invalid option. Please choose 1, 2, or 3.";

      generateFlake = { srcString, packageDRVandSTR }:
        let
          inherit (packageDRVandSTR.drv) name version src;
          packageFlake = {
            description = "A flake containing the created package";

            inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

            outputs = { self, nixpkgs }:
              let
                system = "x86_64-linux";
                pkgs = import nixpkgs { inherit system; };
              in {
                packages.${system}.default = {
                  inherit name version;
                  src = packageDRVandSTR.drv;

                  # meta = {
                  #   description = package.meta.description;
                  #   license = package.meta.license;
                  # };
                };
              };
          };

          packageFlakeString = # nix #
            ''
              {
                description = "A flake containing the package";
                inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

                outputs =
                  { self, nixpkgs }:
                  let
                    system = "x86_64-linux";
                    pkgs = import nixpkgs { inherit system; };
                  in
                  {
                    packages.''${system}.default = ${packageDRVandSTR.str};
                }; 
              }                     
            '';
        in { inherit packageFlake packageFlakeString; };

    in {

      legacyPackages.${system} = {
        generatedFlake1 = generatePackage {
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
        generatedFlake2 = generatePackage {
          url = "https://github.com/lestrrat-go/jwx";
          version = "v3.0.6";
          hash = "sha256-D3HhkAEW1vxeq6bQhRLe9+i/0u6CUhR6azWwIpudhBI=";
          vendorHash = "sha256-FjNUcNI3A97ngPZBWW+6qL0eCTd10KUGl/AzByXSZt8=";
          option = 2; # options - 1 2 3 4
          extraArgs = { modRoot = "cmd/jwx"; };
        };
        generatedFlake3 = generatePackage {
          url = "https://github.com/OpenTTD/nml";
          version = "0.7.6";
          hash = "sha256-jAvzfmv8iLs4jb/rzRswiAPHZpx20hjfbG/NY4HGcF0=";
          option = 2; # options - 1 2 3 4
        };
        generatedFlake4 = generatePackage {
          url = "https://github.com/evmar/n2";
          hash = "sha256-eWcN/iK/ToufABi4+hIyWetp2I94Vy4INHb4r6fw+TY=";
          option = 2; # options - 1 2 3 4
        };
        callPackage1 = generatePackage {
          url = "https://github.com/cfoust/cy";
          rev = "77ea96a";
          version = "v1.5.1";
          hash = "sha256-lRBggQqi5F667w2wkMrbmTZu7DX/wHD5a4UIwm1s6V4=";
          vendorHash = null;
          option = 3; # options - 1 2 3 4
          extraArgs = with pkgs; {
            buildInputs = [ "xorg.libX11" ];
            doCheck = false;
          };
        };
        nixPackage1 = generatePackage {
          url = "https://github.com/cfoust/cy";
          rev = "77ea96a";
          version = "v1.5.1";
          hash = "sha256-lRBggQqi5F667w2wkMrbmTZu7DX/wHD5a4UIwm1s6V4=";
          vendorHash = null;
          option = 4; # options - 1 2 3 4
          extraArgs = with pkgs; {
            buildInputs = [ "xorg.libX11" ];
            doCheck = false;
          };
        };
        nixPackage2 = generatePackage {
          url = "https://github.com/LoLei/razer-cli";
          version = "2.3.0";
          hash = "sha256-uwTqDCYmG/5dyse0tF/CPG+9SlThyRyeHJ0OSBpcQio=";
          option = 4; # options - 1 2 3 4
          extraArgs = with pkgs; { };
        };
        nixPackage3 = generatePackage {
          url = "https://codeberg.org/svartstare/pass2csv/";
          version = "v1.2.0";
          hash = "sha256-AzhKSfuwIcw/iizizuemht46x8mKyBFYjfRv9Qczr6s=";
          option = 4; # options - 1 2 3
          extraArgs = with pkgs; { };
        };

        demoPackage1 =  generatePackage {
          url = "https://github.com/cfoust/cy";
          rev = "77ea96a";
          version = "v1.5.1";
          hash = "sha256-lRBggQqi5F667w2wkMrbmTZu7DX/wHD5a4UIwm1s6V4=";
          vendorHash = null;
          option = 1; # options - 1 2 3 4
          extraArgs = with pkgs; {
            buildInputs = [ xorg.libX11 ];
            doCheck = false;
          };
        };
        demoPackage2 =  generatePackage {
          url = "https://github.com/OpenTTD/nml";
          version = "0.7.6";
          hash = "sha256-jAvzfmv8iLs4jb/rzRswiAPHZpx20hjfbG/NY4HGcF0=";
          option = 2; # options - 1 2 3 4
        };
        demoPackage3 =  generatePackage {
          url = "https://github.com/lestrrat-go/jwx";
          version = "v3.0.7";
          hash = "sha256-vR7QsRAVdYmi7wYGsjuQiB1mABq5jx7mIRFiduJRReA=";
          vendorHash = "sha256-fpjkaGkJUi4jrdFvrClx42FF9HwzNW5js3I5HNZChOU=";
          option = 3; # options - 1 2 3 4
          extraArgs = { modRoot = "cmd/jwx"; };
        };
        
        demoPackage4 =  generatePackage {
          url = "https://github.com/cfoust/cy";
          rev = "77ea96a";
          version = "v1.5.1";
          hash = "sha256-lRBggQqi5F667w2wkMrbmTZu7DX/wHD5a4UIwm1s6V4=";
          vendorHash = null;
          option = 4; # options - 1 2 3 4
          extraArgs = with pkgs; {
            buildInputs = [ xorg.libX11 ];
            doCheck = false;
          };
        };
      };

      packages.${system} = {
        #python
        examplePackage1 = generatePackage {
          url = "https://github.com/OpenTTD/nml";
          version = "0.7.6";
          hash = "sha256-jAvzfmv8iLs4jb/rzRswiAPHZpx20hjfbG/NY4HGcF0=";
          option = 1; # options - 1 2 3 4
        };
        examplePackage2 = generatePackage {
          url = "https://github.com/OpenTTD/nml";
          version = "0.7.6";
          hash = "sha256-jAvzfmv8iLs4jb/rzRswiAPHZpx20hjfbG/NY4HGcF0=";
          option = 1; # options - 1 2 3 4
        };
        examplePackage3 = generatePackage {
          url = "https://codeberg.org/svartstare/pass2csv/";
          version = "v1.2.0";
          hash = "sha256-AzhKSfuwIcw/iizizuemht46x8mKyBFYjfRv9Qczr6s=";
          option = 4; # options - 1 2 3 4
          extraArgs = with pkgs; { };
        };

        #rust
        examplePackage4 = generatePackage {
          url = "https://github.com/evmar/n2";
          hash = "sha256-eWcN/iK/ToufABi4+hIyWetp2I94Vy4INHb4r6fw+TY=";
          option = 1; # options - 1 2 3 4
        };
        examplePackage5 = generatePackage {
          url = "https://gitlab.com/kornelski/mandown";
          rev = "9da94876";
          hash = "sha256-wEv7h3Kl4EczmsY4FuGOvRgeGf0rgANhONhCKyu6zik=";
          option = 1; # options - 1 2 3 4
        };
        examplePackage6 = generatePackage {
          url = "https://crates.io/crates/petname";
          version = "3.0.0-alpha.2";
          hash = "sha256-6gJkaHAhau2HKKwVa/FL1mZfC9IJkyORm5P8MzLnQ5Q=";
          option = 1; # options - 1 2 3 4
        };

        #go
        examplePackage7 = generatePackage {
          url = "https://github.com/lestrrat-go/jwx";
          version = "v3.0.7";
          hash = "sha256-vR7QsRAVdYmi7wYGsjuQiB1mABq5jx7mIRFiduJRReA=";
          vendorHash = "sha256-fpjkaGkJUi4jrdFvrClx42FF9HwzNW5js3I5HNZChOU=";
          option = 1; # options - 1 2 3 4
          extraArgs = { modRoot = "cmd/jwx"; };
        };
        examplePackage8 = generatePackage {
          url = "https://github.com/cfoust/cy";
          rev = "77ea96a";
          version = "v1.5.1";
          hash = "sha256-lRBggQqi5F667w2wkMrbmTZu7DX/wHD5a4UIwm1s6V4=";
          vendorHash = null;
          option = 1; # options - 1 2 3 4
          extraArgs = with pkgs; {
            buildInputs = [ xorg.libX11 ];
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
