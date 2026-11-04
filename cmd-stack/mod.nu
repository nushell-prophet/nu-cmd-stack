# A module to scroll through the list of commands using `ctrl+alt+j/k` shortcuts
# The list of commands can be piped to `cmd-stack init`.

# Thanks to @weirdan for the inspiration!
# https://discord.com/channels/601130461678272522/615253963645911060/1270752014506397736

# The folder of stack files that `cmd-stack load` completes from.
# Why a fixed path, not `$nu.data-dir`: an agent writes there from its own
# processes, and `$nu.data-dir` differs between Linux and macOS.
const default_dir = '~/.local/share/nushell/cmd-stacks'

# Show current state of cmd-stack
@category history
export def main []: nothing -> oneof<record, nothing> {
    $env.cmd-stack?
    | if $in == null {
        print 'cmd-stack is empty. Use `cmd-stack init`'
    } else { }
}

# Initialize cmd-stack
export def --env init [
    commands?: list
    --quiet # don't print help instructions
    --force-keybindings # force keybindings add
] {
    let commands = $in
        | if $commands == null { } else { $commands }

    $env.cmd-stack = {
        index: -1
        stack: $commands
    }

    default-keybindings | apply-keybindings --force=$force_keybindings --quiet=$quiet

    if not $quiet {
        if $commands == null {
            print 'Pipe the list of your commands to `cmd-stack init`'
        } else {
            print $'(stack-length) items added to cmd-stack.'
            print 'use `ctrl+alt+j/k` for scrolling through them.'
        }
    }
}

# Load a stack file into cmd-stack
#
# A stack file is a Nushell script whose blocks, split by empty lines, are the
# commands. A first block of only comments describes the stack: completion shows
# it, and it is not loaded. An agent writes stack files into the stacks folder,
# `$env.CMD_STACK_DIR` or `~/.local/share/nushell/cmd-stacks`, and each show of
# their commands is reported for `cmd-stack runs`.
@category history
@example "load a demo script as a stack" { cmd-stack load demo.nu }
export def --env load [
    stack: string@"nu-complete cmd-stack stacks" # a name in the stacks folder, or a path to a file
]: nothing -> nothing {
    let file = stack-path $stack

    $env.cmd-stack = {
        index: -1
        stack: (stack-commands $file)
        source: $file
    }

    print $'(stack-length) items loaded from ($file).'
    print 'use `ctrl+alt+k` for the first one.'
}

# Push commands to the end of cmd-stack
@example "push a sequence" { ['ls' 'print done'] | cmd-stack push }
export def --env push [
    cmd?: string # the command; without it, the commands come from the pipeline
]: [nothing -> nothing string -> nothing list<string> -> nothing] {
    let commands = if $cmd != null { [$cmd] } else { [$in] | flatten | compact }
        | where ($it | str trim | is-not-empty)

    if ($commands | is-empty) { return }

    if $env.cmd-stack? == null {
        $env.cmd-stack = {index: -1 stack: []}
    }

    $env.cmd-stack.stack = ($env.cmd-stack.stack | append $commands)
    commandline edit --replace ''
}

# The commands of a stack file that a shell showed, each joined with the history
# row that ran after the show: whoever wrote the file reads the outcome here.
# Of several shows in a row, the last one counts: the shell ran nothing between them.
@category history
export def runs [
    stack: string@"nu-complete cmd-stack stacks" # a name in the stacks folder, or a path to a file
    --history-db: path # the sqlite history of the shells; the one in the nushell config dir by default
]: nothing -> table {
    let file = stack-path $stack
    let log = shown-log

    if not ($log | path exists) { return [] }

    let history = open ($history_db | default (history-db))

    open --raw $log
    | from json --objects
    | reverse
    | uniq-by nu_session history_id
    | reverse
    | where stack == $file
    | each {|shown|
        let run = $history
            | query db 'select command_line, exit_status, duration_ms from history where session_id = ? and id > ? order by id limit 1' --params [$shown.nu_session ($shown.history_id | default 0)]
            | get --optional 0

        {
            index: $shown.index
            command: $shown.command
            pane: $shown.pane
            shown_at: $shown.at
            ran: $run.command_line?
            exit_status: $run.exit_status?
            duration: ($run.duration_ms? | if $in == null { } else { into duration --unit ms })
        }
    }
}

def "nu-complete cmd-stack stacks" []: nothing -> record {
    let dir = stacks-dir

    if not ($dir | path exists) { return {completions: []} }

    let completions = ls $dir
        | where type == file and ($it.name | str ends-with '.nu')
        | sort-by modified --reverse
        | each {|f|
            let blocks = stack-blocks $f.name
            let about = $blocks
                | first 1
                | where {|block| $block | is-description }
                | each { lines | first | str replace --regex '^#\s*' '' }

            {
                value: ($f.name | path parse | get stem)
                description: (
                    [
                        (stack-commands $f.name | length | if $in == 1 { '1 command' } else { $'($in) commands' })
                        ($f.modified | date humanize)
                        ...$about
                    ]
                    | str join ' · '
                )
            }
        }

    # Why no sort: the newest stack, the one an agent just wrote, comes first
    {completions: $completions options: {sort: false}}
}

def stacks-dir []: nothing -> path {
    $env.CMD_STACK_DIR? | default $default_dir | path expand
}

# The log of the shows of loaded commands, one JSON object per line.
# Not a file next to each stack because: completion lists the folder.
def shown-log []: nothing -> path {
    stacks-dir | path join shown.jsonl
}

# A name in the stacks folder first, then a path
def stack-path [stack: string]: nothing -> path {
    let named = stacks-dir | path join $'($stack).nu'
    let given = $stack | path expand

    if not ($named | path exists) and not ($given | path exists) {
        error make {msg: $'no stack ($stack): neither ($named) nor a file at that path'}
    }

    if ($named | path exists) { $named } else { $given }
}

def stack-blocks [file: path]: nothing -> list<string> {
    open --raw $file
    | split row --regex '\n\s*\n'
    | str trim
    | where ($it | is-not-empty)
}

def is-description []: string -> bool {
    lines | all { str trim | str starts-with '#' }
}

def stack-commands [file: path]: nothing -> list<string> {
    let blocks = stack-blocks $file

    if ($blocks | is-not-empty) and ($blocks | first | is-description) {
        $blocks | skip
    } else {
        $blocks
    }
}

# The sqlite history of the shells.
# Not `$nu.history-path` because: under `nu --commands` no config sets the
# sqlite format, and that path names `history.txt`.
def history-db []: nothing -> path {
    $nu.default-config-dir | path join history.sqlite3
}

# Record which command of a stack file this shell showed, and after which
# history row, so that `cmd-stack runs` finds the row that ran it.
# Why at the show and not in a `pre_execution` hook: the user does not want
# cmd-stack to install hooks.
def report-shown [stack: path index: int command: string]: nothing -> nothing {
    # Why `%`: this module exports its own `history` command
    let session = %history session
    let db = history-db
    let last = if ($db | path exists) {
        open $db
        | query db 'select max(id) as id from history where session_id = ?' --params [$session]
        | get 0.id
    }
    let log = shown-log

    mkdir ($log | path dirname)
    {
        stack: $stack
        index: $index
        command: $command
        pane: $env.ZELLIJ_PANE_ID?
        zellij_session: $env.ZELLIJ_SESSION_NAME?
        nu_session: $session
        history_id: $last
        at: (date now)
    }
    | to json --raw
    | $in + "\n"
    | save --append $log
}

# Apply keybindings with conflict detection.
# Pipe a list of keybinding records. Identical existing bindings are skipped.
# Conflicts are reported — use --force to override them.
def --env apply-keybindings [
    --force  # Override conflicting keybindings
    --quiet  # Don't print information message
] {
    let bindings = $in
    let normalize_mod = {|m| $m | split row '_' | sort | str join '_' }

    let results = $bindings | each {|binding|
            let norm_mod = do $normalize_mod $binding.modifier
            let matches = $env.config.keybindings | where {|kb|
                    (do $normalize_mod $kb.modifier) == $norm_mod and $kb.keycode == $binding.keycode
                }

            if ($matches | is-empty) {
                {status: new binding: $binding conflict: null}
            } else {
                let identical = $matches | where event == $binding.event

                if ($identical | is-not-empty) {
                    {status: identical binding: $binding conflict: null}
                } else {
                    {status: conflict binding: $binding conflict: ($matches | first)}
                }
            }
        }

    let to_add = $results | where status in [new conflict]
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

        if not $quiet { print $'($n) keybindings applied.' }
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

def stack-length []: nothing -> int {
    $env.cmd-stack.stack | length
}

def --env cmd-cycle [
    steps: int
]: nothing -> nothing {
    if $env.cmd-stack?.index? == null {
        commandline edit --replace "# cmd-stack is empty. Initialize it using `cmd-stack init`"
        return
    }
    let index = $env.cmd-stack.index + $steps
    let stack_length = stack-length

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
        let command = $env.cmd-stack.stack | get $index

        if $env.cmd-stack.source? != null { report-shown $env.cmd-stack.source $index $command }
        $command
    }
    | commandline edit --replace $in
}

# Default keybindings for cmd-stack
def default-keybindings []: nothing -> list<record> {
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

# add commands from n-last-history sessesion into cmd-stack with template `[session commands] | cmd-stack init` for interactive pick
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
        | $'($in) | cmd-stack init --quiet'
    }
    | init
}
