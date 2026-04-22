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
    }

    $env.cmd-stack = {
        index: -1
        stack: $commands
    }

    default-keybindings | apply-keybindings

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

# Apply keybindings with conflict detection.
# Pipe a list of keybinding records. Identical existing bindings are skipped.
# Conflicts are reported — use --force to override them.
def --env apply-keybindings [
    --force  # Override conflicting keybindings
] {
    let bindings = $in
    let normalize_mod = {|m| $m | split row '_' | sort | str join '_' }

    let results = $bindings | each {|binding|
        let norm_mod = do $normalize_mod $binding.modifier
        let matches = $env.config.keybindings | where {|kb|
            (do $normalize_mod $kb.modifier) == $norm_mod and $kb.keycode == $binding.keycode
        }

        if ($matches | is-empty) {
            {status: new, binding: $binding, conflict: null}
        } else {
            let identical = $matches | where {|kb| $kb.event == $binding.event }
            if ($identical | is-not-empty) {
                {status: identical, binding: $binding, conflict: null}
            } else {
                {status: conflict, binding: $binding, conflict: ($matches | first)}
            }
        }
    }

    let to_add = $results | where status in [new, conflict]
    let identical = $results | where status == identical
    let conflicts = $results | where status == conflict

    if ($identical | is-not-empty) {
        let n = $identical | length
        print $'($n) already set — skipped.'
    }

    if ($conflicts | is-not-empty) and (not $force) {
        let n = $conflicts | length
        print $'($n) conflicts found — nothing applied:'
        $conflicts | each {|c|
            let kb = $c.conflict
            let name = $kb.name? | default 'unnamed'
            print $'  ($c.binding.modifier)+($c.binding.keycode) is bound to "($name)"'
        }
        print 'Use --force to override.'
        return
    }

    if ($to_add | is-not-empty) {
        $env.config.keybindings ++= ($to_add | get binding)
        let n = $to_add | length
        print $'($n) keybindings applied.'
    }
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

# Default keybindings for cmd-stack
def default-keybindings [] {
    [
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
