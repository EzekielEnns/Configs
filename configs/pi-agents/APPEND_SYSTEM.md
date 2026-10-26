## Writing files

Your output per message is limited (about 16k tokens, thinking included). A file write that
runs past it is cut off and not applied.

- Write a new file in parts: a short skeleton first (types, signatures, stubs), then fill it in
  with edits of at most ~150 lines each.
- To change an existing file, edit the part that changes; don't rewrite the whole file.
- Run the build and tests after each part, and fix errors before writing more.
