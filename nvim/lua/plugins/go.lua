-- go.nvim: Go helpers on top of gopls (tests, struct tags, impl, iferr,
-- coverage, debugging). gopls itself is configured in lspconfig.lua and
-- golangci-lint runs as its own language server (golangci_lint_ls).
-- Binaries: NixOS gets them from modules/nvim.nix; macOS uses brew go +
-- `go-tools-install` (darwin/home.nix) so the toolchain tracks upstream.
return {
	"ray-x/go.nvim",
	ft = { "go", "gomod", "gosum", "gowork" },
	dependencies = {
		"ray-x/guihua.lua",
		"neovim/nvim-lspconfig",
		"nvim-treesitter/nvim-treesitter",
		-- :GoDebug / :GoBreakToggle
		"mfussenegger/nvim-dap",
		{ "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" } },
		"theHamsta/nvim-dap-virtual-text",
	},
	opts = {
		-- nvim-treesitter is on the `main` branch (see nvim-treesitter.lua)
		treesitter_main = true,
		-- gopls is set up in lspconfig.lua; don't let go.nvim start a second one
		lsp_cfg = false,
		lsp_inlay_hints = { enable = true },
		-- formatting on save is handled by conform.nvim (golangci-lint fmt)
		gofmt = "gofumpt",
		goimports = "goimports",
		-- send :GoLint / :GoVet / test failures to trouble.nvim instead of quickfix
		trouble = true,
		luasnip = true,
		-- :GoAddTag defaults
		tag_transform = false,
		tag_options = "json=omitempty",
		-- tests
		test_runner = "go",
		run_in_floaterm = true,
		-- go.nvim reads the misspelled key; keep both in case upstream fixes it
		floaterm = { posititon = "right", position = "right", width = 0.45, height = 0.98 },
		-- debugging via delve
		dap_debug = true,
		dap_debug_gui = {},
		dap_debug_keymap = true,
		dap_debug_vt = { enabled = true, enabled_commands = true, all_frames = true },
		icons = { breakpoint = "●", currentpos = "▶" },
	},
}
