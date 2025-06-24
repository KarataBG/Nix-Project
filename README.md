Nix Project README

Overview

This project utilizes Nix flakes to manage dependencies and build configurations. The following instructions will guide you through the setup and execution of the project.

Prerequisites

Ensure you have Nix installed on your system.

Familiarity with Nix and its command-line interface is recommended.

Execution Steps

Clone the Repository

Start by cloning the repository to your local machine:

git clone https://github.com/KarataBG/Nix-Project

1. Testing flake creation/ execution

Create a Demo Folder

mkdir demo

cd demo

Evaluate the Flake

Run the following command to evaluate the flake and generate the flake.nix file or the second command to see the created flake:

nix eval ../Nix-Project/#legacyPackages.x86_64-linux.generatedFlake${1-4}.packageFlakeString --raw > flake.nix

nix eval ../Nix-Project/#legacyPackages.x86_64-linux.generatedFlake${1-4}.packageFlakeString --raw

Build the Project

After generating the flake.nix, build the project using:

nix build

Show Flake Information

To display information about the flake, use the command:

nix flake show


2. Testing package generation

Enter flake folder

cd Nix-Project

Run the flake

nix build .#examplePackage${1-6}

3. Testing callPackage

Create your own flake

Import the flake

importedPackage = pkgs.callPackage originalFlake.packages.x86_64-linux.callPackage1 {};


License

This project is licensed under the MIT License. See the LICENSE file for more information.
