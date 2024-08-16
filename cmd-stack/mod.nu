# show current state of cmd-stack
export def main [] {
    $env.cmd-stack?
    | if $in == null {
        print 'cmd-stack is empty. Use `cmd-stack init`'
    } else {}
}

# initialize cmd-stack
export def --env init [
    commands?: list
] {
    let $commands = if $commands == null {} else { $commands }
        | default []

    $env.cmd-stack = {
        index: -1
        stack: $commands
    }

    if 'cmd-stack-next' not-in $env.config.keybindings.name {
        setup-keybindings
    }
}

def --env update-index [
    steps?: int = 1
    --set: int
] {
    let index = if $set != null { $set } else {
        ($env.cmd-stack?.index? | default (-1)) + $steps
    }

    $env.cmd-stack.index = $index

    $index
}

export def --env next [] {
    update-index 1
    | command-to-line
}

export def --env prev [] {
    update-index (-1)
    | command-to-line
}

def --env command-to-line [] {
    let $index = $in
    let $stack_length = $env.cmd-stack.stack | length

    if $index > ($stack_length - 1) {
        update-index (-1)
        ($"# There are only ($stack_length) commands in the stack, and you are at the very end of it.\n" +
        "# Use `cmd-stack prev` or the corresponding keybinding.")
    } else if $index < 0 {
        update-index 1
        $"# You are at the beginning of the stack. Use `cmd-stack next` or the corresponding keybinding."
    } else {
        $env.cmd-stack.stack
        | get $index
    }
    | commandline edit -r $in
}

def setup-keybindings [] {
    # I use commandline edit here as I can't modify keybindings from custom command
    # bugreport: https://github.com/nushell/nushell/issues/13636
    let $closure = {
        $env.config.keybindings = (
            $env.config.keybindings
            | append [
                {
                    name: cmd-stack-next
                    modifier: control_alt
                    keycode: char_k
                    mode: [emacs, vi_normal, vi_insert]
                    event: {
                        send: executehostcommand
                        cmd: 'cmd-stack next'
                    }
                }
                {
                    name: cmd-stack-prev
                    modifier: control_alt
                    keycode: char_j
                    mode: [emacs, vi_normal, vi_insert]
                    event: {
                        send: executehostcommand
                        cmd: 'cmd-stack prev'
                    }
                }
            ]
            | uniq-by name modifier keycode
        )
    }

    view source $closure
    | str substring 2..-2
    | commandline edit -r $in
}
