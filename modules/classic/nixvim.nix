{ pkgs, ... }:

{
  environment.variables.EDITOR = "nvim";
  environment.variables.VISUAL = "nvim";
  programs.nixvim = {
    enable = true;
    plugins = {
      lualine.enable = true;
      neo-tree.enable = true;
	  lspconfig.enable = true;
	  blink-cmp = {
	    enable = true;
		settings = {
		  keymap = { preset = "super-tab"; };
		  sources = { default = ["lsp" "path" "snippets" "buffer" ]; };
		};
	  };
	  web-devicons.enable = true;
	  
	  telescope = {
        enable = true;
        extensions = {
          fzf-native.enable = true;
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
		config = {
		  keymap = {
		    preset = "super-tab";  # Makes Tab work like VSCode
		  };
		  sources = {
		    default = ["lsp" "path" "snippets" "buffer"];
		  };
		};
	  };
	  pyrefly.enable = true;
	  lua_ls.enable = true;
	  markdown_oxide.enable = true;
	  docker_language_server.enable = true;
	};
	autoGroups = {
      highlight_yank = {
        clear = true;
      };
    };
	autoCmd = [
      {
        event = ["TextYankPost"];
        group = "highlight_yank";
        callback.__raw = ''
          function()
            vim.highlight.on_yank({ timeout = 200 })
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
        action.__raw = "vim.lsp.buf.format";
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
