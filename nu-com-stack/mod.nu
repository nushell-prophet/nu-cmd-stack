export def --env init [
    commands?: list = ['print a' 'print b' 'print c']
] {
    $env.nuqueue = {
        cursor: -1
        stack: $commands
    }
}

export def --env increment-cursor [
    steps?: int = 1
    --reset
] {
    let cursor = if $reset { 0 } else { $env.nuqueue.cursor + $steps }
        | [0 $in]
        | math max

    $env.nuqueue.cursor = $cursor

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

    $env.nuqueue.stack
    | get -i $cursor
    | default $'# There are no commands left. Cursor poistion is ($cursor)'
    | commandline edit -r $in
}
