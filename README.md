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
