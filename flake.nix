{
  description = "Personal nvf configuration flake (flake-parts style)";

  # Pin base channels and helper flakes consumed by nvf.
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";

    nvf = {
      url = "github:NotAShelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
  };

  # Delegate per-system wiring to flake-parts for consistency.
  outputs =
    inputs@{
      self,
      flake-parts,
      nixpkgs,
      nvf,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      # Build for the two Linux architectures I target.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      # Library exports reuseable nvf settings and helper builders.
      flake.lib = {
        # High-level nvf module that shapes Neovim behaviour.
        nvfSettings = pkgs: {
          # Core Neovim UX defaults and feature toggles.
          vim = {
            globals = {
              mapleader = " ";
              maplocalleader = " ";
            };
            options = {
              termguicolors = true;
              mouse = "a";
              updatetime = 250;
              wrap = false;
              splitbelow = true;
              splitright = true;
            };
            keymaps = [
              {
                mode = [ "n" ];
                key = "<leader>ff";
                action = "<cmd>Telescope find_files<cr>";
                desc = "Telescope find files";
              }
              {
                mode = [ "n" ];
                key = "<leader>fg";
                action = "<cmd>Telescope live_grep<cr>";
                desc = "Telescope live grep";
              }
              {
                mode = [ "n" ];
                key = "<leader>fb";
                action = "<cmd>Telescope buffers<cr>";
                desc = "Telescope buffers";
              }
              {
                mode = [ "n" ];
                key = "<leader>fh";
                action = "<cmd>Telescope help_tags<cr>";
                desc = "Telescope help tags";
              }
            ];
            theme = {
              enable = true;
              name = "tokyonight";
              style = "night";
            };
            statusline.lualine.enable = true;
            treesitter.enable = true;
            telescope.enable = true;
            filetree.nvimTree.enable = true;
            git.gitsigns.enable = true;
            lsp = {
              enable = true;
              formatOnSave = true;
              inlayHints.enable = true;
              lightbulb.enable = true;
              lspkind.enable = true;
            };
            autocomplete."blink-cmp" = {
              enable = true;
              friendly-snippets.enable = true;
            };
            snippets.luasnip.enable = true;
            # Language-specific tooling aggregated under nvf's abstraction.
            languages = {
              enableTreesitter = true;
              enableFormat = true;
              enableExtraDiagnostics = true;
              # Nix-language tooling for declarative configs.
              nix = {
                enable = true;
                extraDiagnostics = {
                  enable = true;
                  types = [
                    "statix"
                    "deadnix"
                  ];
                };
                format = {
                  enable = true;
                  package = pkgs.alejandra;
                  type = "alejandra";
                };
                lsp = {
                  enable = true;
                  package = pkgs.nixd;
                  server = "nixd";
                };
                treesitter.enable = true;
              };
              # Lua stack for authoring Neovim configuration.
              lua = {
                enable = true;
                format = {
                  enable = true;
                  package = pkgs.stylua;
                  type = "stylua";
                };
                lsp = {
                  enable = true;
                  lazydev.enable = true;
                };
                treesitter.enable = true;
              };
            };
          };
        };

        # Helper that turns nvf modules into a package derivation.
        mkNeovim =
          pkgs:
          nvf.lib.neovimConfiguration {
            inherit pkgs;
            modules = [ { config = self.lib.nvfSettings pkgs; } ];
          };
      };

      # Concrete outputs for each system assembled from helpers above.
      perSystem =
        {
          system,
          pkgs,
          ...
        }:
        let
          neovimCfg = self.lib.mkNeovim pkgs;
        in
        {
          # Publish Neovim derivations for `nix build` consumers.
          packages = {
            default = neovimCfg.neovim;
            nvf = neovimCfg.neovim;
          };

          # Wire `nix run` to launch the packaged Neovim binary.
          apps.default = {
            type = "app";
            program = "${neovimCfg.neovim}/bin/nvim";
          };

          # Expose alejandra so `nix fmt` matches repo preferences.
          formatter = pkgs.alejandra;

          # Provide a shell with language servers and linters.
          devShells.default = pkgs.mkShell {
            packages = [
              neovimCfg.neovim
              pkgs.nixd
              pkgs.ruff
            ];
          };
        };

      # Re-export nvf modules tailored with my defaults for NixOS systems.
      flake.nixosModules.default =
        { pkgs, ... }:
        {
          imports = [ nvf.nixosModules.default ];
          programs.nvf = {
            enable = true;
            settings = self.lib.nvfSettings pkgs;
          };
        };

      # Companion Home Manager module for user-level Neovim installs.
      flake.homeManagerModules.default =
        { pkgs, ... }:
        {
          imports = [ nvf.homeManagerModules.default ];
          programs.nvf = {
            enable = true;
            settings = self.lib.nvfSettings pkgs;
          };
        };
    };
}
