# nu-cmd-stack (cmd-stack)

## Quick start

```nushel no-run
> git clone https://github.com/nushell-prophet/nu-cmd-stack; cd nu-cmd-stack
> use cmd-stack
```

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
