export def --env init [
    commands?: list
] {
    let $commands = if $commands == null {} else { $commands }
        | default []

    $env.nu-com-stack = {
        index: -1
        stack: $commands
    }

    if 'nu-com-stack-next' not-in $env.config.keybindings.name {
        add-keybindings
    }
}

export def --env increment-index [
    steps?: int = 1
    --reset
] {
    let index = if $reset { 0 } else {
            $env.nu-com-stack?.index?
            | default (-1)
            | $in + $steps
        }
        | [0 $in]
        | math max

    $env.nu-com-stack.index = $index

    $index
}

export def --env next [] {
    increment-index 1
    | command-to-line
}

export def --env prev [] {
    increment-index (-1)
    | command-to-line
}

def command-to-line [] {
    let $index = $in

    $env.nu-com-stack?.stack?
    | get -i $index
    | default $'# There are no commands left. The poistion of index is ($index)'
    | commandline edit -r $in
}

def add-keybindings [] {
    let $closure = {
        $env.config.keybindings = (
            $env.config.keybindings
            | append [
                {
                    name: nu-com-stack-next
                    modifier: control_alt
                    keycode: char_k
                    mode: [emacs, vi_normal, vi_insert]
                    event: {
                        send: executehostcommand
                        cmd: 'nu-com-stack next'
                    }
                }
                {
                    name: nu-com-stack-prev
                    modifier: control_alt
                    keycode: char_j
                    mode: [emacs, vi_normal, vi_insert]
                    event: {
                        send: executehostcommand
                        cmd: 'nu-com-stack prev'
                    }
                }
            ]
            | uniq-by name modifier keycode
        )
    }

    view source $closure
    | lines
    | skip
    | drop
    | str join (char nl)
    | commandline edit -r $in
}
