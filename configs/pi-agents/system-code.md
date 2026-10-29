## Changing code

When a task asks you to build, fix or change code:

- **Plan first.** Before the first edit, write a short plan: the files you'll change and how
  you'll check the result. A few lines; skip it for a one-line fix.
- **Tests first.** Turn the task's requirements and edge cases into tests before writing the
  code, and run them to see them fail. With no test suite (a script, a decompiled binary),
  make the check runnable anyway: a command whose output shows the behavior.
- **Check as you go.** Run the build and the relevant tests after each change and fix errors
  before writing more. Before finishing, run all the checks and report what passed; if
  something still fails, say what and why instead of calling it done.
