-- In-buffer markdown rendering (headings, tables, code blocks, checkboxes,
-- callouts) via conceal + extmarks. Deliberately starts OFF so markdown opens
-- raw; `:RenderMarkdown toggle` flips it for the session, `buf_toggle` for one
-- buffer, and `:RenderMarkdown preview` opens a rendered copy to the side.
return {
	"MeanderingProgrammer/render-markdown.nvim",
	ft = { "markdown" },
	cmd = { "RenderMarkdown" },
	dependencies = {
		"nvim-treesitter/nvim-treesitter", -- needs the markdown + markdown_inline parsers
		"nvim-tree/nvim-web-devicons",
	},
	---@module "render-markdown"
	---@type render.md.UserConfig
	opts = {
		-- Raw first. Nothing is concealed until you ask for it.
		enabled = false,
		-- While rendering, the line the cursor sits on still shows its true
		-- text, so editing never happens against concealed syntax.
		anti_conceal = { enabled = true },
	},
}
