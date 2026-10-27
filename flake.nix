{
  description = "Ada-EFI: UEFI development library and ELF to PE converter for Ada";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = f:
        nixpkgs.lib.genAttrs systems
          (system: f (import nixpkgs { inherit system; }));
    in
    {
      packages = forAllSystems (pkgs:
        let
          adaEfi = pkgs.callPackage ./nix/ada-efi.nix { };
        in
        {
          default = adaEfi;
          inherit adaEfi;
          elf2efi = pkgs.callPackage ./nix/elf2efi.nix { };
        });

      devShells = forAllSystems (pkgs:
        let
          adaEfi = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
        in
        {
          default = pkgs.mkShell {
            inputsFrom = [ adaEfi ];
            packages = with pkgs; [
              gnat
              gnumake
              qemu
              OVMF
              mtools
              dosfstools
            ];
            shellHook = ''
              echo "Ada-EFI dev shell"
              echo "  make        build the library and examples"
              echo "  make test   boot the examples under QEMU/OVMF"
            '';
          };
        });

      overlays.default = final: prev: {
        ada-efi = self.packages.${final.stdenv.hostPlatform.system}.default;
        elf2efi = self.packages.${final.stdenv.hostPlatform.system}.elf2efi;
      };

      # Convenience helper for downstream flakes:
      #   ada-efi.lib.mkAdaEfiApp pkgs { name = "app"; src = ./.; }
      lib.mkAdaEfiApp = pkgs: attrs:
        pkgs.callPackage ./nix/mk-app.nix {
          adaEfi = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
        } attrs;
    };
}
