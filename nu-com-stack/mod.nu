export def --env init [
    commands?: list = ['print a' 'print b' 'print c']
] {
    $env.nu-com-stack = {
        cursor: -1
        stack: $commands
    }
}

export def --env increment-cursor [
    steps?: int = 1
    --reset
] {
    let cursor = if $reset { 0 } else {
            $env.nu-com-stack?.cursor?
            | default (-1)
            | $in + $steps
        }
        | [0 $in]
        | math max

    $env.nu-com-stack.cursor = $cursor

    $cursor
}

export def --env next [] {
    increment-cursor 1
    | commandline-cursor
}

export def --env prev [] {
    increment-cursor (-1)
    | commandline-cursor
}

def commandline-cursor [] {
    let $cursor = $in

    $env.nu-com-stack?.stack?
    | get -i $cursor
    | default $'# There are no commands left. The poistion of cursor is ($cursor)'
    | commandline edit -r $in
}
