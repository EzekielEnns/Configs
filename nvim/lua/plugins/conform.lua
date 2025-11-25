return {
	"stevearc/conform.nvim",
	opts = {
		formatters_by_ft = {
			python = {
				"ruff_fix",
				"ruff_format",
				"ruff_organize_imports",
			},
			lua = { "stylua" },
			javascript = {
				"prettierd",
				"prettier",
				"eslint_d", --[[ stop_after_first = true ]]
			},
			typescript = {
				"prettierd",
				"prettier",
				"eslint_d",--[[ stop_after_first = true ]]
			},
			typescriptreact = { "prettierd", "prettier", "eslint_d", stop_after_first = true },
			javascriptreact = { "prettierd", "prettier", "eslint_d", stop_after_first = true },
			rust = { "rustfmt" },
			nix = { "alejandra", "nixfmt", "nixpkgs_fmt" },
		},
		format_on_save = {
			timeout_ms = 500,
			lsp_format = "fallback",
		},
		formatters = {
			rustfmt = {},
			alejandra = {
				stdin = false,
			},
			nixfmt = {
				stdin = true,
			},
			nixpkgs_fmt = {
				stdin = true,
			},
		},
	},
}
