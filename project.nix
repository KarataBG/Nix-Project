{ pkgs ? import <nixpkgs> {} }:

let
     # Функция за извличане на owner и repo от GitHub URL
  parseGitHubUrl = url: let
    parts = pkgs.lib.strings.splitString "/" url;
    websiteSource = builtins.elemAt parts 2;
    owner = builtins.elemAt parts 3; # Третият елемент е owner
    repo = builtins.elemAt parts 4;  # Четвъртият елемент е repo
  in
    { websiteSource = websiteSource; owner = owner; repo = repo; }; # Връщаме set с owner и repo

  generatePackage = { url, rev, tag, option, hash }:
    let
      parsed = parseGitHubUrl url; # Извличане на owner и repo
      websiteSource = parsed.websiteSource;
      owner = parsed.owner;
      repo = parsed.repo;

      name = "${repo}-automated-package";
      version = tag;
      src = pkgs.fetchFromGitHub {
        inherit owner repo;
        tag = tag;
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
        pkgs.python3Packages.buildPythonApplication {          
          inherit (package) meta name version src;

        pyproject = true;

        dependencies = with pkgs.python3Packages; [
          setuptools
          ply
          pillow
        ];
       
        }

      else
        throw "Invalid option. Please choose 1, 2, or 3.";
in
{
  examplePackage1 = generatePackage {
    url = "https://github.com/LoLei/razer-cli"; # Примерен URL
    rev = "4b979a4";
    tag = "0.7.6";
    hash = "sha256-jjCMxY0PEar9F4O4vu5niU2U74rxoaBczqW5CKLEKvk=";
    option = 1; # Изберете опция 1, 2 или 3
  };

}