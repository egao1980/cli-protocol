# cli-protocol

CLOS CLI protocol for [cl-stack](https://github.com/egao1980/cl-stack): define commands/options, parse `argv` (POSIX ∪ PowerShell ∪ CMD), run handlers.

| System | Role |
|--------|------|
| `cli-protocol` (`stack-cli`) | Protocol + `normalize-argv` |
| `cli-backend-clingon` | Default (subcommands) |
| `cli-backend-adopt` | Alternate (flat) |

```lisp
(asdf:load-system "cli-backend-clingon")
(stack-cli:run *app* :argv '("greet" "-Count" "2" "ada")) ; PowerShell wire
```

Brief: `cl-stack/docs/capabilities/cli.md`

## Built-in `--help` / `--version`

clingon adds `--help` and `--version` to every command (a command cannot define its own). The protocol reports them instead of printing and exiting:

- `stack-cli:parse` → the options plist gets `:help t` / `:version t` when the flag was given on the matched command or a parent. Nothing is printed; required-option checks are skipped for that command.
- `stack-cli:run` → writes the usage (or the version line) to `*standard-output*` and signals `cli-help-requested` / `cli-version-requested` (both `cli-exit`, code 0, reader `cli-exit-command-name`) instead of calling the handler. `stack-cli:main` exits 0.

## Option values

A token after a known value-taking option is its value, verbatim: `--name -x`, `-n /etc/hosts`, `-Name -Verbose` and `/Name /x` are not rewritten as options. For unknown options the dialect heuristics still apply.
