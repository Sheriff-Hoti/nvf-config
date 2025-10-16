{
  description = "Personal nvf configuration flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nvf = {
      url = "github:notashelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nvf, ... }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forEachSystem = lib.genAttrs systems;

      nvfSettings = pkgs: {
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

          autocomplete = {
            blink-cmp = {
              enable = true;
              friendly-snippets.enable = true;
            };
          };

          snippets.luasnip.enable = true;

          languages = {
            enableTreesitter = true;
            enableFormat = true;
            enableExtraDiagnostics = true;

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
              lsp.enable = true;
              treesitter.enable = true;
            };

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

            python = {
              enable = true;
              format = {
                enable = true;
                package = pkgs.python312Packages.black;
                type = "black";
              };
              lsp = {
                enable = true;
                package = pkgs.pyright;
              };
              treesitter.enable = true;
            };
          };
        };
      };

      mkNeovim = pkgs:
        nvf.lib.neovimConfiguration {
          inherit pkgs;
          modules = [
            {
              config = nvfSettings pkgs;
            }
          ];
        };
    in {
      packages = forEachSystem (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          neovimCfg = mkNeovim pkgs;
        in {
          default = neovimCfg.neovim;
          nvf = neovimCfg.neovim;
        }
      );

      apps = forEachSystem (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          neovimPackage = (mkNeovim pkgs).neovim;
        in {
          default = {
            type = "app";
            program = "${neovimPackage}/bin/nvim";
          };
        }
      );

      formatter = forEachSystem (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.alejandra
      );

      devShells = forEachSystem (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in {
          default = pkgs.mkShell {
            packages = [
              (mkNeovim pkgs).neovim
              pkgs.nil
              pkgs.ruff
            ];
          };
        }
      );

      nixosModules.default = { pkgs, ... }: {
        imports = [ nvf.nixosModules.default ];
        programs.nvf = {
          enable = true;
          settings = nvfSettings pkgs;
        };
      };

      homeManagerModules.default = { pkgs, ... }: {
        imports = [ nvf.homeManagerModules.default ];
        programs.nvf = {
          enable = true;
          settings = nvfSettings pkgs;
        };
      };

      lib = {
        inherit nvfSettings mkNeovim;
      };
    };
}
