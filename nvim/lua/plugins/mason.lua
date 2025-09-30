return {
	"williamboman/mason.nvim",
	opts = {
		registries = {
			"github:mason-org/mason-registry",
			"github:Crashdummy/mason-registry",
		},
		ensure_installed = {
			"roslyn",
		},
	},
}
