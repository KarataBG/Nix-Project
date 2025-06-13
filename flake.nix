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
      generatePackage = { url, rev, version, option, hash }: let
        parsed = parseGitHubUrl url;

        owner = parsed.owner;
        repo = parsed.repo;

        name = "${repo}-automated-package";
        # version = version;
        inherit version;

        src = pkgs.fetchFromGitHub {
          inherit owner repo rev;
          # rev = release;
          hash = hash;
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

          # isPyProject = builtins.hasAttr "pyproject.toml" src;
          # isGo = builtins.hasAttr "go.mod" src;
          # isRust = builtins.hasAttr "Cargo.toml" src; 
      
      in          

        if option == 1 then
          # Option 1: direct application build standard nix-2 packet
          # pkgs.python3Packages.buildPythonApplication {


        # inherit isPython isPyProject isGo isRust;

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
              pyproject = true;
              dependencies = with pkgs.python3Packages; [
              setuptools ply pillow
            ];            
            }
          else if isGo then
            pkgs.buildGoModule { inherit src name version; }
          else if isRust then
            pkgs.buildRustPackage { inherit src name version; }
          else
            throw "Unknown language or missing necessary build files. Please check your source structure."
  











          # pkgs.stdenv.mkDerivation rec {


          #   buildInputs = with pkgs;[ python3 go rustc cargo ];
          #   nativeBuildInputs = with pkgs;[ makeWrapper python3Packages.setuptools];

          #   buildPhase = ''
          #     ${pkgs.python3.interpreter} setup.py build
          #   '';
          #   installPhase = ''
          #     ${pkgs.python3.interpreter} setup.py install
          #   '';

          #   buildPhase = ''
          #     echo "Debug build phase..."

          #     # Build Python package
          #     if [ -d "python" ]; then
          #     python3 setup.py build
          #     python3 setup.py install --prefix=$out
          #     echo "Python build complete."
          #     fi

          #     # Build Go package
          #     if [ -d "go" ]; then
          #       cd ${repo}
          #       go build -o FILENAME
          #     fi

          #     # Build Rust package
          #     if [ -d "rust" ]; then
          #       # cd ${repo}
          #       cargo build --release
          #     fi
          #   '';

          #   installPhase = ''
          #     mkdir -p $out/bin

          #     # Python: If a Python binary is generated
          #     if [ -f "${repo}" ]; then
          #       cp ${repo} $out/bin/
          #     else
          #       echo "Python binary not found!"
          #     fi

          #     # Go: If the Go binary is generated
          #     if [ -f "go/${repo}-automated-package" ]; then
          #       cp go/${repo}-automated-package $out/bin/
          #     else
          #       echo "Go binary not found!"
          #     fi

          #     # Rust: If the Rust binary is generated
          #     if [ -f "target/release/${repo}" ]; then
          #       cp target/release/${repo} $out/bin/
          #     else
          #       echo "Rust binary not found!"
          #     fi
          #   '';

          #   inherit (package) name version src meta;

          #   # buildInputs = with pkgs.python3Packages; [setuptools ply pillow];
          #   # installPhase = ''
          #           # mkdir -p $out/bin
          #           # cp -r $src/* $out/
          #         # '';
            
          # }
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
        rev = "9ce5688";
        version = "2.3.0";
        hash = "sha256-uwTqDCYmG/5dyse0tF/CPG+9SlThyRyeHJ0OSBpcQio=";
        option = 1;  # options - 1 2 3
      };

      inherit (generatePackage) src isPython isPyProject isGo isRust;
    };
}

#ako podam rev wzima nmlc dori i drugite da sa na razer


# sha256-uwTqDCYmG/5dyse0tF/CPG+9SlThyRyeHJ0OSBpcQio=
# razer 2.3.0

# sha256-jAvzfmv8iLs4jb/rzRswiAPHZpx20hjfbG/NY4HGcF0= 
# nmlc

# sha256-jjCMxY0PEar9F4O4vu5niU2U74rxoaBczqW5CKLEKvk=
# razer