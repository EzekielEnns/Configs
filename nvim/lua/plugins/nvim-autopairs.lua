return {
	"saghen/blink.pairs",
	version = "*", -- (recommended) only required with prebuilt binaries

	-- download prebuilt binaries from github releases
	dependencies = "saghen/blink.download",
	-- OR build from source, requires nightly:
	-- https://rust-lang.github.io/rustup/concepts/channels.html#working-with-nightly-rust
	-- build = 'cargo build --release',
	-- If you use nix, you can build from source using latest nightly rust with:
	-- build = 'nix run .#build-plugin',

	--- @module 'blink.pairs'
	--- @type blink.pairs.Config
	opts = {
		mappings = {
			-- you can call require("blink.pairs.mappings").enable()
			-- and require("blink.pairs.mappings").disable()
			-- to enable/disable mappings at runtime
			enabled = true,
			-- and/or with `vim.g.blink_pairs = false` and `vim.b.blink_pairs = false`
			disabled_filetypes = {},
			-- see the defaults:
			-- https://github.com/Saghen/blink.pairs/blob/main/lua/blink/pairs/config/mappings.lua#L14
			pairs = {},
		},
		highlights = {
			enabled = true,
			groups = {
				"BlinkPairsOrange",
				"BlinkPairsPurple",
				"BlinkPairsBlue",
			},

			-- highlights matching pairs under the cursor
			matchparen = {
				enabled = true,
				group = "BlinkPairsMatchParen",
			},
		},
		debug = false,
	},
}
