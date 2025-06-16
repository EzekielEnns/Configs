require("typescript-tools").setup {
  settings = {
    tsserver_file_preferences = {
      includeInlayParameterNameHints = "all",
      includeCompletionsForModuleExports = true,
      quotePreference = "auto",
      importModuleSpecifierPreference= "non-relative",
      updateImportsOnFileMove= "always",
      importModuleSpecifierEnding="minimal"
    },
    separate_diagnostic_server = false,
    publish_diagnostic_on = "change",
    expose_as_code_action = {},
    tsserver_max_memory = "auto",
    tsserver_locale = "en",
    complete_function_calls = false,
    include_completions_with_insert_text = true,
    code_lens = "off",
    disable_member_code_lens = false,
    jsx_close_tag = {
        enable = true,
        filetypes = { "javascriptreact", "typescriptreact" },
    }
  },
}