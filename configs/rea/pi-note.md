
## In Pi: REA is a command, not MCP tools

Here REA isn't connected as an MCP server, and that's intended: don't run `npx`, `rea setup`,
`rea update` or `rea doctor --client ...`, and don't install anything for it. Every REA tool
this skill names is the `rea` command with dashes: `inspect_wasm_artifact` is
`rea inspect-wasm-artifact <path>`. `rea --help` lists the commands and `rea <command> --help`
their options; add `--format json` (or `md`) to read the output. WABT 1.0.42 and Ghidra are
already wired in, and `wasm2wat`, `wasm-objdump`, `wasm-decompile`, `wasm-opt` and
`wasm-tools` are on PATH.

