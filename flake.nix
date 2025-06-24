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
            ${if option == 4 then "" else "pkgs."}fetchFromGitHub {
                repo = "${repo}";
                owner = "${owner}";
                tag = "${version}";
                hash = "${hash}";
              };
          '';
        } else if websiteSource == "gitlab.com" then {
          drv = fetchGitLab;
          srcString = ''
            ${if option == 4 then "" else "pkgs."}fetchFromGitLab {
                repo = "${repo}";
                owner = "${owner}";
                tag = "${version}";
                version = "${version}";
              };
          '';
        } else if websiteSource == "chromium.googlesource.com" then {
          drv = fetchGitiles;
          srcString = ''
            ${if option == 4 then "" else "pkgs."}fetchFromGitiles {
                url = "${websiteSource}";
                hash = "${hash}";
                rev = "${rev}";
                version = "${version}";
              };
          '';
        } else if websiteSource == "crates.io" then {
          drv = fetchCrate;
          srcString = ''
            ${if option == 4 then "" else "pkgs."}.fetchCrate {
                pname = "${repo}";
                hash = "${hash}";
                version = "${version}";
              };
          '';
        } else if websiteSource == "codeberg.org" then {
          drv = fetchGitea;
          srcString = ''
            ${if option == 4 then "" else "pkgs."}fetchFromGitea{
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

          # Run the above script to get dependencies
          commandedDependencies = pkgs.runCommand "get-dependencies" {
            inherit src;
            buildInputs = [
              pkgs.python3
              pkgs.python3Packages.setuptools
            ];
          } ''
            ${pkgs.python3}/bin/python3 ${extractDependencies} > $out
          '';

          #Specific python package resolving
          resolveDeps = dep: pkgs.python3Packages.${dep};
          removeEmpties = list: builtins.filter (x: x != "") list;
          splitFile = lib.splitString "\n" (builtins.readFile commandedDependencies);

          #Generic package resolving
          resolvePackage = pkg: 
              let
                parts = lib.splitString "." pkg;
                resolved = if checkForPath pkg then builtins.foldl' (acc: part: acc.${part}) pkgs parts  # Adding the namespaces one by one
                  else throw "  Add the package name surrounded with \"\" ";
              in
                resolved;

          checkForPath = pkg:
            builtins.isString pkg;

          resolveBuildInputs = list: builtins.map resolvePackage list;
          resolvedInputs = resolveBuildInputs (extraArgs.buildInputs or []);

          extraArgsCombiSetter = ''
            ${if builtins.hasAttr "modRoot" extraArgs then
              if builtins.isString extraArgs.modRoot then ''modRoot = "${extraArgs.modRoot}";'' else throw "modRoot has to be string"
            else
              ""}
            ${
              if builtins.hasAttr "buildInputs" extraArgs then
                "buildInputs = with pkgs; [ ${
                  if (builtins.any (input: builtins.isString input)) extraArgs.buildInputs then 
                    builtins.concatStringsSep " " extraArgs.buildInputs 
                  else throw " Add the package name surrounded with \"\" "
                } ];"
              else
                ""
            } 
            ${if builtins.hasAttr "doCheck" extraArgs then
              if builtins.isBool extraArgs.doCheck then 
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
              buildInputs = resolvedInputs;
              doCheck = extraArgs.doCheck or true;

              dependencies = with pkgs.python3Packages;  [
                (builtins.concatStringsSep " " (builtins.map (resolveDeps) (removeEmpties (splitFile))))
                setuptools
                ply
                pillow
              ];
            };

            str = ''
              ${if option == 4 then "" else "pkgs."}python3Packages.buildPythonApplication rec {
                  name = "${name}";
                  version = "${version}";
                  src = ${srcString}
                  dependencies = with pkgs.python3Packages; [
                    ${(builtins.concatStringsSep " " (removeEmpties (splitFile)))}
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
              buildInputs = resolvedInputs;
              doCheck = extraArgs.doCheck or true;

            };

            str = ''
              ${if option == 4 then "" else "pkgs."}buildGoModule rec {
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
              buildInputs = resolvedInputs;
              doCheck = extraArgs.doCheck or true;

              cargoLock = rustCargoLock;
            };

            str = ''
              ${if option == 4 then "" else "pkgs."}rustPlatform.buildRustPackage rec {
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
          generateNixPackage { inherit packageDRVandSTR;}
        else if option == 2 then
        # Option 2: returns a flake with the package
          generateFlake { inherit srcString packageDRVandSTR; }
        else if option == 3 then
        # Option 3: Defines package for callPackage {}
          generateCallPackage {inherit packageDRVandSTR;}
        else throw "Invalid option. Please choose 1, 2, or 3.";

      generateNixPackage = {packageDRVandSTR}:
        let
          nixCall = packageDRVandSTR.drv;
          nixCallString = ''
            with import <nixpkgs> {};
            ${packageDRVandSTR.str}
          '';
        in
          {inherit nixCall nixCallString;};

      generateCallPackage = {packageDRVandSTR}: 
        let
          packageCall = { pkgs, lib }: "${packageDRVandSTR.drv}";
          packageCallString = ''
            { pkgs, lib }:
            ${packageDRVandSTR.str}
          '';
        in { inherit packageCall packageCallString;};



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
        packageGenerator = {
          url,
          rev ? "",
          version ? "1.0.0",
          option ? 1,
          hash ? lib.trace "Generate hash for input with nix build" "",
          vendorHash ? lib.trace "Generate vendorHash for input with nix build" "",
          extraArgs ? {}
        }: 
          generatePackage {
            inherit url rev version option hash vendorHash extraArgs;
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
