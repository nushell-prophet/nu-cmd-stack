# A module to scroll through the list of commands using `ctrl+alt+j/k` shortcuts
# The list of commands can be piped to `cmd-stack init`.

# Thanks to @weirdan for the inspiration!
# https://discord.com/channels/601130461678272522/615253963645911060/1270752014506397736

# Show current state of cmd-stack
export def main [] {
    $env.cmd-stack?
    | if $in == null {
        print 'cmd-stack is empty. Use `cmd-stack init`'
    } else {}
}

# Initialize cmd-stack
export def --env init [
    commands?: list
] {
    let $commands = $in
        | if $commands == null {} else { $commands }

    if $commands == null {
        print 'Pipe the list of your commands to `cmd-stack init`'
        return
    }

    $env.cmd-stack = {
        index: -1
        stack: $commands
    }

    $env.config.keybindings
    | get -i event.cmd
    | compact
    | where $it =~ 'cmd-stack'
    | is-empty
    | if $in { setup-keybindings }
}

# Get next command from cmd-stack
export def --env next [] {
    cmd-cycle 1
}

# Get previous command from cmd-stack
export def --env prev [] {
    cmd-cycle (-1)
}

def --env cmd-cycle [
    $steps
] {
    if $env.cmd-stack?.index? == null {
        commandline edit -r "# cmd-stack is empty. Initialize it using `cmd-stack init`"
        return
    }
    let $index = $env.cmd-stack.index + $steps
    let $stack_length = $env.cmd-stack.stack | length

    if $index > ($stack_length - 1) {
        ($"# There are only ($stack_length) commands in the stack, and you are at the very end of it.\n" +
        "# Use `cmd-stack prev` or the `ctrl+alt+j` keybinding.")
    } else if $index < 0 {
        $env.cmd-stack.index = -1
        $"# You are at the beginning of the stack. Use `cmd-stack next` or or the `ctrl+alt+k` keybinding."
    } else {
        $env.cmd-stack.index = $index

        $env.cmd-stack.stack
        | get $index
    }
    | commandline edit -r $in
}

def --env setup-keybindings [] {
        # Add keybindings for `cmd-stack`
        $env.config.keybindings ++= [
            {
                modifier: control_alt
                keycode: char_k
                mode: [emacs, vi_normal, vi_insert]
                event: { send: executehostcommand cmd: 'cmd-stack next' }
            }
            {
                modifier: control_alt
                keycode: char_j
                mode: [emacs, vi_normal, vi_insert]
                event: { send: executehostcommand cmd: 'cmd-stack prev' }
            }
        ]
}
