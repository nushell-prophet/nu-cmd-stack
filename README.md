# nu-cmd-stack (cmd-stack)

## Quick start

```nushel no-run
> git clone https://github.com/nushell-prophet/nu-cmd-stack; cd nu-cmd-stack
> use cmd-stack
```

## Demo

https://github.com/user-attachments/assets/862f2eb7-0635-429a-99c4-d3f5ec8e8a7d

[(high res youtube)](https://youtu.be/wBMm1bFlbaU)

## Examples

```nushell no-run
# Initialize `cmd-stack` with the list of 3 commands.
# After executing it will suggest you to add two shortcuts. Execute the suggestion.
> ['print "this"' 'print "that"' "# check ls\nls"] | cmd-stack init

# Scroll through the commands using `ctrl + alt + j/k`
```

```nushell no-run
# Here we fill `cmd-stack` with the commands from `demo.nu`.
# We divide commands here by empty lines
> open demo.nu | split row "\n\n" | skip | cmd-stack init
```

```nushell no-run
# Here we put previous session commands into `cmd-stack`
> let prev_session_id = history -l | last 100 | get session_id | uniq | last 2 | first
> history -l | where session_id == $prev_session_id | get command | cmd-stack init
```

## Stacks in files

A stack file is a Nushell script whose blocks, split by empty lines, are the commands,
like `demo.nu`.
A first block of only comments describes the stack and is not loaded.
`cmd-stack load` puts the commands of a file into the stack of this shell,
and the keys that `cmd-stack init` bound scroll through them:

```nushell no-run
> cmd-stack load demo.nu
```

`cmd-stack load <Tab>` completes the names of the stack files in `$env.CMD_STACK_DIR`,
`~/.local/share/nushell/cmd-stacks` by default, newest first,
with the number of commands, the age and the description.
A script or an agent that wants you to run commands writes a file there,
and you load it when you are ready.

Each time `ctrl+alt+j/k` shows a command of a loaded file,
cmd-stack adds a line to `shown.jsonl` in that folder:
the zellij pane, the history session of the shell, and the last history row of that session.
`cmd-stack runs <stack>` joins these lines with the sqlite history
and shows the row that ran each command, with its exit status and duration.
