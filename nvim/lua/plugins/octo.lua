-- GitHub PRs and issues without leaving nvim: list them, read the conversation
-- thread, walk the diff file by file, leave review comments, approve or request
-- changes. Drives the `gh` CLI, so it uses the auth you already have.
--
-- Entry point is <leader>gr. Inside a PR buffer:
--   :Octo review start      open the diff in a review pane
--   :Octo review submit     approve / request changes / comment
--   :Octo comment add       comment on the line under the cursor
--   :Octo pr checkout       check the branch out locally
return {
	"pwntester/octo.nvim",
	cmd = "Octo",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"folke/snacks.nvim",
		"nvim-tree/nvim-web-devicons",
	},
	opts = {
		-- Defaults to telescope, which this config does not have. snacks is the
		-- picker everything else here already uses.
		picker = "snacks",
	},
}
