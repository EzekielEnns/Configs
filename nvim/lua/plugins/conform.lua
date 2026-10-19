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
			-- `golangci-lint fmt --stdin`: runs whatever formatters.enable lists in
			-- the nearest .golangci.yml (falls back to ~/.golangci.yml from
			-- configs/files.nix, which enables gofumpt + goimports).
			go = { "golangci-lint" },
			nix = { "alejandra", "nixfmt", "nixpkgs_fmt" },
		},
		format_on_save = {
			timeout_ms = 500,
			lsp_format = "fallback",
		},
		formatters = {
			rustfmt = {},
			["golangci-lint"] = {
				-- run from the project root so config discovery starts there.
				-- Resolved lazily: the spec is read before conform is loaded.
				cwd = function(self, ctx)
					return require("conform.util").root_file({
						".golangci.yml",
						".golangci.yaml",
						".golangci.toml",
						".golangci.json",
						"go.mod",
					})(self, ctx)
				end,
			},
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
