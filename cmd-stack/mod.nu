# A module to scroll through the list of commands using `ctrl+alt+j/k` shortcuts
# The list of commands can be piped to `cmd-stack init`.

# Thanks to @weirdan for the inspiration!
# https://discord.com/channels/601130461678272522/615253963645911060/1270752014506397736

# Show current state of cmd-stack
export def main [] {
    $env.cmd-stack?
    | if $in == null {
        print 'cmd-stack is empty. Use `cmd-stack init`'
    } else { }
}

# Initialize cmd-stack
export def --env init [
    commands?: list
] {
    let $commands = $in
    | if $commands == null { } else { $commands }

    if $commands == null {
        print 'Pipe the list of your commands to `cmd-stack init`'
        return
    }

    $env.cmd-stack = {
        index: -1
        stack: $commands
    }

    $env.config.keybindings
    | default null event.cmd
    | get -o event.cmd
    | compact
    | where $it =~ 'cmd-stack'
    | is-empty
    | if $in { setup-keybindings }

    [
        $'(stack-length) items added to cmd-stack.'
        'use `ctrl+alt+j/k` for scrolling through them.'
    ]
    | to text
    | print
}

# Push a command to the end of cmd-stack
export def --env push [cmd: string] {
    cmd-push $cmd
}

def --env cmd-push [cmd: string] {
    if ($cmd | str trim | is-empty) { return }

    if $env.cmd-stack? == null {
        $env.cmd-stack = {index: -1, stack: []}
    }

    $env.cmd-stack.stack = ($env.cmd-stack.stack | append $cmd)
    commandline edit -r ''
}

# Check if cmd-stack keybindings conflict with existing ones
export def check-keybindings [] {
    let ours = [
        [modifier keycode cmd];
        [control char_s 'cmd-stack push']
        [control_alt char_k 'cmd-stack next']
        [control_alt char_j 'cmd-stack prev']
    ]

    let conflicts = $ours | each {|binding|
        $env.config.keybindings
        | where {|kb|
            $kb.keycode == $binding.keycode and (
                $kb.modifier == $binding.modifier or
                # account for modifier aliases (e.g. control_alt vs alt_control)
                $kb.modifier == ($binding.modifier | split row '_' | reverse | str join '_')
            )
        }
        | where {|kb|
            ($kb.event.cmd? | default '') !~ 'cmd-stack'
        }
        | each {|kb|
            {
                key: $'($binding.modifier)+($binding.keycode)'
                cmd_stack_cmd: $binding.cmd
                conflict_name: ($kb.name? | default '(unnamed)')
                conflict_event: ($kb.event | to nuon)
            }
        }
    }
    | flatten

    if ($conflicts | is-empty) {
        print 'No conflicts found in $env.config.keybindings.'
    } else {
        print 'Conflicts found:'
        print ($conflicts | table)
    }

    # Warn about known terminal-level issues
    print ''
    print '# Note: ctrl+s may be intercepted by terminal XOFF (flow control).'
    print '# This cannot be detected from nushell. Fix with: stty -ixon'
    print '# Reedline built-in defaults also cannot be checked here.'
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
        [
            $" # There are only ($stack_length) commands in the stack,"
            "# and you are at the very end of it."
            "# Use the `ctrl+alt+j` keybinding or the command `cmd-stack prev`."
        ]
        | to text
    } else if $index < 0 {
        $env.cmd-stack.index = -1
        $"# You are at the beginning of the stack. Use the `ctrl+alt+k` keybinding or `cmd-stack next`."
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
            mode: [emacs vi_normal vi_insert]
            event: {send: executehostcommand cmd: 'cmd-stack next'}
        }
        {
            modifier: control_alt
            keycode: char_j
            mode: [emacs vi_normal vi_insert]
            event: {send: executehostcommand cmd: 'cmd-stack prev'}
        }
        # ctrl+s to push — inspired by Claude Code's submit keybinding.
        # Note: ctrl+s may conflict with terminal XOFF (flow control).
        # If so, disable it with `stty -ixon` or use one of these alternatives:
        # - ctrl+alt+p (p for push)
        # - ctrl+alt+s (s for store/stack)
        {
            modifier: control
            keycode: char_s
            mode: [emacs vi_normal vi_insert]
            event: {send: executehostcommand cmd: 'cmd-stack push (commandline)'}
        }
    ]
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
