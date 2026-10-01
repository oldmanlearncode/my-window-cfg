#!/usr/bin/env zsh

set -euo pipefail

# ============================================================
# Rust + NeoVim development environment for Ubuntu
# - Rust via rustup
# - NeoVim stable from official GitHub release tarball
# - Rust tooling: rust-analyzer, rust-src, rustfmt, clippy
# - NeoVim: lazy.nvim, TokyoNight, blink.cmp, Telescope,
#            WhichKey, GitSigns, nvim-lspconfig
# - Rust LSP, format-on-save, inlay hints, Cargo shortcuts
#
# Managed NeoVim config marker:
#   -- managed-by: install-rust-nvim.zsh
# ============================================================

readonly SCRIPT_NAME="${0:t}"

log() {
  print -P "%F{cyan}==>%f $*"
}

ok() {
  print -P "%F{green}✔%f $*"
}

warn() {
  print -P "%F{yellow}WARN:%f $*"
}

die() {
  print -P "%F{red}ERROR:%f $*" >&2
  exit 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# ------------------------------------------------------------
# 0. Basic checks
# ------------------------------------------------------------

if [[ "$(uname -s)" != "Linux" ]]; then
  die "Script này chỉ dành cho Linux/Ubuntu."
fi

if [[ -r /etc/os-release ]]; then
  source /etc/os-release

  if [[ "${ID:-}" != "ubuntu" ]]; then
    warn "Distro hiện tại là '${ID:-unknown}', không phải Ubuntu. Script vẫn thử tiếp tục."
  fi
fi

case "$(uname -m)" in
  x86_64|amd64)
    NVIM_ARCH="x86_64"
    ;;
  aarch64|arm64)
    NVIM_ARCH="arm64"
    ;;
  *)
    die "Architecture chưa được hỗ trợ: $(uname -m)"
    ;;
esac

readonly LOCAL_BIN="$HOME/.local/bin"
readonly LOCAL_OPT="$HOME/.local/opt"
readonly NVIM_INSTALL_DIR="$LOCAL_OPT/nvim"
readonly NVIM_CONFIG_DIR="$HOME/.config/nvim"
readonly NVIM_ASSET="nvim-linux-${NVIM_ARCH}"
readonly NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/${NVIM_ASSET}.tar.gz"

mkdir -p "$LOCAL_BIN" "$LOCAL_OPT" "$HOME/.config"

# ------------------------------------------------------------
# 1. Ubuntu packages
# ------------------------------------------------------------

log "Cài system dependencies..."

sudo apt-get update

APT_PACKAGES=(
  ca-certificates
  curl
  git
  unzip
  tar
  gzip
  ripgrep
  fd-find
  build-essential
  pkg-config
  libssl-dev
  xclip
  wl-clipboard
)

sudo apt-get install -y "${APT_PACKAGES[@]}"

# Ubuntu names fd as fdfind.
if command_exists fdfind; then
  ln -sf "$(command -v fdfind)" "$LOCAL_BIN/fd"
fi

ok "System dependencies đã sẵn sàng."

# ------------------------------------------------------------
# 2. Shell PATH
# ------------------------------------------------------------

add_path_block() {
  local file="$1"
  local begin_marker="# >>> rust-nvim-dev-path >>>"
  local end_marker="# <<< rust-nvim-dev-path <<<"

  touch "$file"

  if ! grep -Fq "$begin_marker" "$file"; then
    cat >> "$file" <<'EOF'

# >>> rust-nvim-dev-path >>>
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
# <<< rust-nvim-dev-path <<<
EOF
  fi
}

add_path_block "$HOME/.zprofile"
add_path_block "$HOME/.zshrc"

export PATH="$LOCAL_BIN:$HOME/.cargo/bin:$PATH"

ok "PATH đã được thêm vào ~/.zprofile và ~/.zshrc."

# ------------------------------------------------------------
# 3. Rust / rustup
# ------------------------------------------------------------

log "Cài / cập nhật Rust stable bằng rustup..."

if ! command_exists rustup; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --default-toolchain stable --profile default
fi

# shellcheck disable=SC1090
if [[ -f "$HOME/.cargo/env" ]]; then
  source "$HOME/.cargo/env"
fi

export PATH="$HOME/.cargo/bin:$PATH"

rustup set profile default
rustup toolchain install stable
rustup default stable
rustup update stable

log "Cài Rust developer components..."

rustup component add \
  rust-analyzer \
  rust-src \
  rustfmt \
  clippy

ok "Rust + rust-analyzer + rustfmt + clippy đã sẵn sàng."

# ------------------------------------------------------------
# 4. NeoVim stable
# ------------------------------------------------------------

log "Cài NeoVim stable chính thức (${NVIM_ARCH})..."

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

curl -fL "$NVIM_URL" -o "$TMP_DIR/nvim.tar.gz"
tar -xzf "$TMP_DIR/nvim.tar.gz" -C "$TMP_DIR"

[[ -d "$TMP_DIR/$NVIM_ASSET" ]] \
  || die "Không tìm thấy thư mục NeoVim sau khi giải nén."

rm -rf "$NVIM_INSTALL_DIR"
mv "$TMP_DIR/$NVIM_ASSET" "$NVIM_INSTALL_DIR"

ln -sfn "$NVIM_INSTALL_DIR/bin/nvim" "$LOCAL_BIN/nvim"

ok "NeoVim: $("$LOCAL_BIN/nvim" --version | head -n 1)"

# ------------------------------------------------------------
# 5. Backup existing NeoVim config
# ------------------------------------------------------------

if [[ -d "$NVIM_CONFIG_DIR" ]]; then
  if [[ ! -f "$NVIM_CONFIG_DIR/init.lua" ]] \
    || ! grep -Fq "managed-by: install-rust-nvim.zsh" "$NVIM_CONFIG_DIR/init.lua"; then

    BACKUP_DIR="${NVIM_CONFIG_DIR}.backup-$(date +%Y%m%d-%H%M%S)"

    log "Phát hiện config NeoVim hiện có."
    log "Backup sang: $BACKUP_DIR"

    mv "$NVIM_CONFIG_DIR" "$BACKUP_DIR"
  fi
fi

mkdir -p "$NVIM_CONFIG_DIR"

# ------------------------------------------------------------
# 6. NeoVim config
# ------------------------------------------------------------

log "Ghi cấu hình NeoVim cho Rust..."

cat > "$NVIM_CONFIG_DIR/init.lua" <<'LUA'
-- managed-by: install-rust-nvim.zsh

-----------------------------------------------------------
-- Leader
-----------------------------------------------------------

vim.g.mapleader = " "
vim.g.maplocalleader = " "

-----------------------------------------------------------
-- Basic options
-----------------------------------------------------------

local opt = vim.opt

opt.number = true
opt.relativenumber = true

opt.termguicolors = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.scrolloff = 8
opt.sidescrolloff = 8

opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.smartindent = true

opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

opt.splitright = true
opt.splitbelow = true

opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.undofile = true
opt.updatetime = 250
opt.timeoutlen = 400
opt.confirm = true

-----------------------------------------------------------
-- Basic keymaps
-----------------------------------------------------------

local map = vim.keymap.set

map("n", "<Esc>", "<cmd>nohlsearch<CR>", {
  desc = "Clear search highlight",
})

map("n", "<leader>w", "<cmd>write<CR>", {
  desc = "Save file",
})

map("n", "<leader>q", "<cmd>quit<CR>", {
  desc = "Quit",
})

-- Window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })

-- Buffer navigation
map("n", "[b", "<cmd>bprevious<CR>", {
  desc = "Previous buffer",
})

map("n", "]b", "<cmd>bnext<CR>", {
  desc = "Next buffer",
})

-- Move selected lines
map("v", "J", ":m '>+1<CR>gv=gv", {
  desc = "Move selection down",
})

map("v", "K", ":m '<-2<CR>gv=gv", {
  desc = "Move selection up",
})

-- Terminal: Esc Esc returns to Normal mode
map("t", "<Esc><Esc>", [[<C-\><C-n>]], {
  desc = "Terminal normal mode",
})

-----------------------------------------------------------
-- Cargo helpers
-----------------------------------------------------------

local function cargo_terminal(command)
  vim.cmd("botright 12split")
  vim.cmd("terminal " .. command)
  vim.cmd("startinsert")
end

map("n", "<leader>rr", function()
  cargo_terminal("cargo run")
end, {
  desc = "Cargo run",
})

map("n", "<leader>rb", function()
  cargo_terminal("cargo build")
end, {
  desc = "Cargo build",
})

map("n", "<leader>rt", function()
  cargo_terminal("cargo test")
end, {
  desc = "Cargo test",
})

map("n", "<leader>rc", function()
  cargo_terminal("cargo clippy")
end, {
  desc = "Cargo clippy",
})

-----------------------------------------------------------
-- Diagnostics
-----------------------------------------------------------

vim.diagnostic.config({
  severity_sort = true,

  virtual_text = {
    spacing = 2,
    prefix = "●",
  },

  float = {
    border = "rounded",
    source = true,
  },

  underline = true,
  signs = true,
})

-----------------------------------------------------------
-- lazy.nvim bootstrap
-----------------------------------------------------------

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
  local output = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })

  if vim.v.shell_error ~= 0 then
    error("Failed to install lazy.nvim:\n" .. output)
  end
end

vim.opt.rtp:prepend(lazypath)

-----------------------------------------------------------
-- Plugins
-----------------------------------------------------------

require("lazy").setup({

  ---------------------------------------------------------
  -- Colorscheme
  ---------------------------------------------------------

  {
    "folke/tokyonight.nvim",

    lazy = false,
    priority = 1000,

    opts = {
      style = "night",
      transparent = true,

      styles = {
        sidebars = "transparent",
        floats = "transparent",
      },
    },

    config = function(_, opts)
      require("tokyonight").setup(opts)
      vim.cmd.colorscheme("tokyonight")

      -- Let WezTerm control the actual window transparency.
      for _, group in ipairs({
        "Normal",
        "NormalNC",
        "NormalFloat",
        "SignColumn",
        "EndOfBuffer",
      }) do
        vim.api.nvim_set_hl(0, group, {
          bg = "none",
        })
      end
    end,
  },

  ---------------------------------------------------------
  -- WhichKey
  ---------------------------------------------------------

  {
    "folke/which-key.nvim",

    event = "VeryLazy",

    opts = {
      preset = "modern",

      spec = {
        { "<leader>f", group = "Find" },
        { "<leader>l", group = "LSP" },
        { "<leader>r", group = "Rust / Cargo" },
      },
    },
  },

  ---------------------------------------------------------
  -- Git integration
  ---------------------------------------------------------

  {
    "lewis6991/gitsigns.nvim",

    event = {
      "BufReadPre",
      "BufNewFile",
    },

    opts = {},
  },

  ---------------------------------------------------------
  -- Telescope
  ---------------------------------------------------------

  {
    "nvim-telescope/telescope.nvim",

    version = "*",

    dependencies = {
      "nvim-lua/plenary.nvim",
    },

    config = function()
      local builtin = require("telescope.builtin")

      map("n", "<leader>ff", builtin.find_files, {
        desc = "Find files",
      })

      map("n", "<leader>fg", builtin.live_grep, {
        desc = "Find text",
      })

      map("n", "<leader>fb", builtin.buffers, {
        desc = "Find buffers",
      })

      map("n", "<leader>fh", builtin.help_tags, {
        desc = "Find help",
      })
    end,
  },

  ---------------------------------------------------------
  -- Autocomplete
  ---------------------------------------------------------

  {
    "saghen/blink.cmp",

    version = "1.*",

    dependencies = {
      "rafamadriz/friendly-snippets",
    },

    opts = {
      keymap = {
        preset = "enter",
      },

      completion = {
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 250,
        },
      },

      signature = {
        enabled = true,
      },

      sources = {
        default = {
          "lsp",
          "path",
          "snippets",
          "buffer",
        },
      },
    },
  },

  ---------------------------------------------------------
  -- LSP
  ---------------------------------------------------------

  {
    "neovim/nvim-lspconfig",

    dependencies = {
      "saghen/blink.cmp",
    },

    config = function()
      local capabilities =
        require("blink.cmp").get_lsp_capabilities()

      vim.lsp.config("rust_analyzer", {
        capabilities = capabilities,

        settings = {
          ["rust-analyzer"] = {
            check = {
              command = "clippy",
            },

            cargo = {
              buildScripts = {
                enable = true,
              },
            },

            procMacro = {
              enable = true,
            },
          },
        },
      })

      vim.lsp.enable("rust_analyzer")
    end,
  },

}, {
  checker = {
    enabled = true,
    notify = false,
  },

  change_detection = {
    notify = false,
  },
})

-----------------------------------------------------------
-- LSP keymaps
-----------------------------------------------------------

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(event)
    local bufnr = event.buf
    local client =
      vim.lsp.get_client_by_id(event.data.client_id)

    local function lsp_map(mode, lhs, rhs, description)
      map(mode, lhs, rhs, {
        buffer = bufnr,
        desc = description,
      })
    end

    -- Navigation
    lsp_map(
      "n",
      "gd",
      vim.lsp.buf.definition,
      "Go to definition"
    )

    lsp_map(
      "n",
      "gD",
      vim.lsp.buf.declaration,
      "Go to declaration"
    )

    lsp_map(
      "n",
      "grr",
      function()
        require("telescope.builtin").lsp_references()
      end,
      "References"
    )

    lsp_map(
      "n",
      "gri",
      function()
        require("telescope.builtin").lsp_implementations()
      end,
      "Implementations"
    )

    -- Refactor
    lsp_map(
      "n",
      "<leader>lr",
      vim.lsp.buf.rename,
      "Rename symbol"
    )

    lsp_map(
      { "n", "v" },
      "<leader>la",
      vim.lsp.buf.code_action,
      "Code action"
    )

    -- Diagnostics
    lsp_map(
      "n",
      "<leader>ld",
      vim.diagnostic.open_float,
      "Show diagnostic"
    )

    lsp_map(
      "n",
      "]d",
      function()
        vim.diagnostic.jump({
          count = 1,
          float = true,
        })
      end,
      "Next diagnostic"
    )

    lsp_map(
      "n",
      "[d",
      function()
        vim.diagnostic.jump({
          count = -1,
          float = true,
        })
      end,
      "Previous diagnostic"
    )

    -- Symbols
    lsp_map(
      "n",
      "<leader>ls",
      function()
        require("telescope.builtin").lsp_document_symbols()
      end,
      "Document symbols"
    )

    -- Format
    lsp_map(
      "n",
      "<leader>lf",
      function()
        vim.lsp.buf.format({
          async = false,
        })
      end,
      "Format file"
    )

    -- Inlay hints
    if
      client
      and client:supports_method("textDocument/inlayHint")
    then
      vim.lsp.inlay_hint.enable(true, {
        bufnr = bufnr,
      })

      lsp_map(
        "n",
        "<leader>lh",
        function()
          local enabled =
            vim.lsp.inlay_hint.is_enabled({
              bufnr = bufnr,
            })

          vim.lsp.inlay_hint.enable(
            not enabled,
            {
              bufnr = bufnr,
            }
          )
        end,
        "Toggle inlay hints"
      )
    end
  end,
})

-----------------------------------------------------------
-- Rust format on save
-----------------------------------------------------------

vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.rs",

  callback = function(event)
    vim.lsp.buf.format({
      bufnr = event.buf,
      async = false,
      timeout_ms = 3000,
    })
  end,
})

-----------------------------------------------------------
-- Notes
-----------------------------------------------------------

-- NeoVim 0.10+ has built-in commenting:
--
--   gcc        toggle comment current line
--   3gcc       toggle comment next 3 lines
--   gc{motion} comment by motion
--   Visual gc  toggle selected lines
--
-- Rust will use // comments automatically.
LUA

ok "Đã tạo $NVIM_CONFIG_DIR/init.lua"

# ------------------------------------------------------------
# 7. Install NeoVim plugins
# ------------------------------------------------------------

log "Cài / đồng bộ NeoVim plugins..."

"$LOCAL_BIN/nvim" --headless "+Lazy! sync" +qa

ok "NeoVim plugins đã được cài."

# ------------------------------------------------------------
# 8. Final verification
# ------------------------------------------------------------

print
log "Kiểm tra versions..."

print "NeoVim:"
"$LOCAL_BIN/nvim" --version | head -n 3

print
print "Rust:"
rustc --version
cargo --version
rustup --version
rust-analyzer --version
rustfmt --version
cargo clippy --version

print
ok "Hoàn tất."

cat <<'EOF'

Bước tiếp theo:

  1. Reload shell:
       exec zsh

  2. Tạo project test:
       mkdir -p ~/projects/rust
       cargo new ~/projects/rust/nvim-demo
       cd ~/projects/rust/nvim-demo
       nvim .

  3. Trong NeoVim kiểm tra LSP:
       :LspInfo
       :checkhealth vim.lsp

Hotkeys chính:

  <Space>ff   Find files
  <Space>fg   Find text
  gd          Go to definition
  K           Hover documentation
  grr         References
  gri         Implementations
  <Space>la   Code action
  <Space>lr   Rename
  <Space>ld   Diagnostic
  ]d / [d     Next / previous diagnostic

  <Space>rr   cargo run
  <Space>rt   cargo test
  <Space>rb   cargo build
  <Space>rc   cargo clippy

  gcc         Comment / uncomment current line
  Visual gc   Comment / uncomment selection

NeoVim background đã được để transparent.
Độ opacity thực tế được điều khiển bởi WezTerm.
EOF
