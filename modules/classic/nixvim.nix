{ lib, pkgs, ... }:
{
  environment.variables.EDITOR = "nvim";
  environment.variables.VISUAL = "nvim";
  programs.nixvim = {
    enable = true;
    plugins = {
      bufferline = {
        enable = true;
        autoLoad = true;
        settings = {
          options = {
            mode = "buffers";
            diagnostics = "nvim_lsp";
            show_buffer_close_icons = true;
            show_close_icon = false;
            separator_style = "slant";
            offsets = [
              {
                filetype = "neo-tree";
                text = "Files";
                highlight = "Directory";
                separator = true;
              }
            ];
          };
        };
      };
      lualine.enable = true;
      neo-tree.enable = true;
      lspconfig.enable = true;
      blink-cmp = {
        enable = true;
        autoLoad = true;
        settings = {
          keymap = {
            preset = "super-tab";
          };
          sources = {
            default = [
              "lsp"
              "path"
              "snippets"
              "buffer"
            ];
            providers.lsp = {
              async = true;
              timeout_ms = 2000;
            };
          };
          completion.trigger = {
            prefetch_on_insert = true;
            show_on_insert = true;
          };
        };
      };
      web-devicons.enable = true;
      telescope = {
        enable = true;
        extensions = {
          fzf-native.enable = true;
        };
      };
      which-key = {
        enable = true;
        autoLoad = true;
        settings = {
          preset = "modern";
          spec = [
            {
              __unkeyed-1 = "<leader>b";
              group = "Buffers";
            }
            {
              __unkeyed-1 = "<leader>f";
              group = "Format";
            }
          ];
        };
      };
    };
    opts = {
      nu = true;
      relativenumber = true;
      clipboard = "unnamedplus";
      tabstop = 4;
      softtabstop = 4;
      shiftwidth = 4;
      winborder = "rounded";
    };
    diagnostic.settings = {
      virtual_text = true;
      signs = true;
      update_in_insert = false;
      underline = true;
      severity_sort = true;
    };

    globals = {
      mapleader = " ";
    };
    lsp.servers = {
      nixd = {
        enable = true;
        config.settings.nixd = {
          nixpkgs.expr = "(builtins.getFlake (\"git+file://\" + toString ./.)).nixosConfigurations.RedNixOs.pkgs";
          formatting.command = [ "${lib.getExe pkgs.nixfmt}" ];
          options = {
            nixos.expr = "(builtins.getFlake (\"git+file://\" + toString ./.)).nixosConfigurations.RedNixOs.options";
          };
        };
      };
      pyrefly.enable = true;
      lua_ls.enable = true;
      markdown_oxide.enable = true;
      docker_language_server.enable = true;
      jsonls.enable = true;
    };
    autoGroups = {
      highlight_yank = {
        clear = true;
      };
      quit_when_only_neotree = {
        clear = true;
      };
    };
    autoCmd = [
      {
        event = [ "TextYankPost" ];
        group = "highlight_yank";
        callback.__raw = ''
          function()
            vim.highlight.on_yank({ timeout = 200 })
          end
        '';
      }
      {
        event = [ "BufEnter" ];
        group = "quit_when_only_neotree";
        callback.__raw = ''
          function()
            local normal_wins = {}
            for _, win in ipairs(vim.api.nvim_list_wins()) do
              if vim.api.nvim_win_get_config(win).relative == "" then
                table.insert(normal_wins, win)
              end
            end

            if #normal_wins ~= 1 then
              return
            end

            local buf = vim.api.nvim_win_get_buf(normal_wins[1])
            if vim.bo[buf].filetype == "neo-tree" then
              vim.cmd("quit")
            end
          end
        '';
      }
    ];
    keymaps = [
      # Open Neo-tree file manager
      {
        mode = "n";
        key = "<leader>e";
        action = "<cmd>Neotree toggle<CR>";
        options = {
          desc = "Toggle Neo-tree";
          silent = true;
        };
      }

      # Bufferline next/prev
      {
        mode = "n";
        key = "<S-l>";
        action = "<cmd>BufferLineCycleNext<CR>";
        options = {
          desc = "Next buffer";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<S-h>";
        action = "<cmd>BufferLineCyclePrev<CR>";
        options = {
          desc = "Prev buffer";
          silent = true;
        };
      }

      # Delete buffer
      {
        mode = "n";
        key = "<leader>bd";
        action = "<cmd>bdelete<CR>";
        options = {
          desc = "Delete buffer";
          silent = true;
        };
      }

      # Go to definition
      {
        mode = "n";
        key = "gd";
        action.__raw = "vim.lsp.buf.definition";
        options = {
          desc = "Go to definition";
          silent = true;
        };
      }

      # LSP format
      {
        mode = "n";
        key = "<leader>fo";
        action.__raw = ''
          function()
            vim.lsp.buf.format({ async = true })
          end
        '';
        options = {
          desc = "LSP format";
          silent = true;
        };
      }

      # Telescope find files
      {
        mode = "n";
        key = "<leader><leader>";
        action = "<cmd>Telescope find_files<CR>";
        options = {
          desc = "Find files";
          silent = true;
        };
      }

      # Telescope live grep
      {
        mode = "n";
        key = "<leader>/";
        action = "<cmd>Telescope live_grep<CR>";
        options = {
          desc = "Live grep";
          silent = true;
        };
      }
    ];
  };
}
