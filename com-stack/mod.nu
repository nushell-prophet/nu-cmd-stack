export def --env init [
    commands?: list
] {
    let $commands = if $commands == null {} else { $commands }
        | default []

    $env.com-stack = {
        index: -1
        stack: $commands
    }

    if 'com-stack-next' not-in $env.config.keybindings.name {
        add-keybindings
    }
}

export def --env increment-index [
    steps?: int = 1
    --reset
] {
    let index = if $reset { 0 } else {
            $env.com-stack?.index?
            | default (-1)
            | $in + $steps
        }
        | [0 $in]
        | math max

    $env.com-stack.index = $index

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

    $env.com-stack?.stack?
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
                    name: com-stack-next
                    modifier: control_alt
                    keycode: char_k
                    mode: [emacs, vi_normal, vi_insert]
                    event: {
                        send: executehostcommand
                        cmd: 'com-stack next'
                    }
                }
                {
                    name: com-stack-prev
                    modifier: control_alt
                    keycode: char_j
                    mode: [emacs, vi_normal, vi_insert]
                    event: {
                        send: executehostcommand
                        cmd: 'com-stack prev'
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
