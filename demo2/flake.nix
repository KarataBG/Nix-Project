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
      packages.${system}.default = pkgs.buildGoModule rec {
  name = "cy-automated-package";
  version = "v1.5.1";
  src = pkgs.fetchFromGitHub {
    repo = "cy";
    owner = "cfoust";
    tag = "v1.5.1";
    hash = "sha256-lRBggQqi5F667w2wkMrbmTZu7DX/wHD5a4UIwm1s6V4=";
  };

  vendorHash = null;
  
buildInputs = with pkgs; [ xorg.libX11 ]; 
doCheck = false;
 
}
;
  }; 
}                     
