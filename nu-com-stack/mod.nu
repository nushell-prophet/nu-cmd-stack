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
    $env.nuqueue.cursor = (
        if $reset { 0 } else {
            $env.nuqueue.cursor + $steps
        }
    )
}

export def --env next [] {
    increment-cursor 1

    $env.nuqueue.stack
    | get -i $env.nuqueue.cursor
    | if $in == null {
        print 'There are no commands left'
    } else {
        commandline edit -r $in
    }
}

export def --env prev [] {
    increment-cursor (-1)

    $env.nuqueue
    | get -i $env.nuqueue.cursor
    | if $in == null {
        print 'There are no commands left'
    } else {
        commandline edit -r $in
    }
}
