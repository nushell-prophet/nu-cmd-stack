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

    [ $'(stack-length) items added to cmd-stack.'
    'use `ctrl+alt+j/k` for scrolling through them.' ]
    | to text
    | print
}

# Get next command from cmd-stack
export def --env next [] {
    cmd-cycle 1
}

# Get previous command from cmd-stack
export def --env prev [] {
    cmd-cycle (-1)
}

def stack-length [] {
    $env.cmd-stack.stack | length
}

def --env cmd-cycle [
    $steps
] {
    if $env.cmd-stack?.index? == null {
        commandline edit -r "# cmd-stack is empty. Initialize it using `cmd-stack init`"
        return
    }
    let $index = $env.cmd-stack.index + $steps
    let $stack_length = stack-length

    if $index > ($stack_length - 1) {
        [ $" # There are only ($stack_length) commands in the stack,"
        "# and you are at the very end of it."
        "# Use `cmd-stack prev` or the `ctrl+alt+j` keybinding." ]
        | to text
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

    [
    "setting keybindings from inside of a module breaks existing keybindings in 0.101, "
    "place the keybindings below into your `config.nu`."

    r#'
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
    '#
    ]
    | str join
    | str replace -rm '^\t\t' ''
    | print
}

alias core_hist = history

export def --env 'history' [
    --last-sessions: int = 10
] {
    open $nu.history-path
    | query db --params [$last_sessions] "
        with sessions as (select distinct(session_id) from history order by id desc limit ?)
        select command_line command, session_id
        from history
        where session_id in sessions
    "
    | group-by session_id
    | values
    | each {
        get command
        | to nuon --indent 2
        | $'($in) | cmd-stack init'
    }
    | init
}
