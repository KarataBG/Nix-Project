{
  description = "Demo flake for showcasing and using demo packages meaningfully";

  inputs = {
    automatorFlake.url = "path:../";
  };

  outputs = { self, automatorFlake, ... }:
    let
      demoPackage1 = automatorFlake.packages.legacyPackages.demoPackage1;
      demoPackage2 = automatorFlake.packages.legacyPackages.demoPackage2;
      demoPackage3 = automatorFlake.packages.legacyPackages.demoPackage3;
      demoPackage4 = automatorFlake.packages.legacyPackages.demoPackage4;

      demoScript = pkgs.writeShellScriptBin "demo-nml" ''
        #!/usr/bin/env bash
        echo "Demonstrating the nml-automated-package:"
        echo "Package Name: ${package.name}"
        echo "Version: ${package.version}"
        echo "Source: ${package.src}"
        echo "Dependencies: ${package.dependencies}"

        # ${package}/bin/nml --help
      '';

    in
    {
      packages = {
        showcaseDemoPackage1 = demoPackage1;
        showcaseDemoPackage2 = demoPackage2;
        showcaseDemoPackage3 = demoPackage3;
        showcaseDemoPackage4 = demoPackage4;
        demoScript = demoScript;
      };

      # Create a development shell that includes all demo packages
      devShell.x86_64-linux = pkgs.mkShell {
        buildInputs = [
          demoPackage1
          demoPackage2
          demoPackage3
          demoPackage4
        ];
        shellHook = ''
          echo "Welcome to the demo shell!"
        '';
      };
    };
}