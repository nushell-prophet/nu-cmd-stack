use std/assert
use std/testing *

use ../cmd-stack

# A fresh stacks folder; `CMD_STACK_DIR` may already be set by the environment
# the tests run in, so every test names its own folder.
def --env stacks-folder []: nothing -> path {
    let dir = mktemp --directory --tmpdir cmd-stacks-XXXXXX

    $env.CMD_STACK_DIR = $dir
    $dir
}

def shown [dir: path]: nothing -> list<record> {
    open --raw ($dir | path join shown.jsonl) | from json --objects
}

const stack_text = "# deploy the thing
# second line of the description

ls

# where am I
pwd


print done
"

@test
def "next and prev walk the stack of the shell" [] {
    ['a' 'b'] | cmd-stack init --quiet

    cmd-stack next
    cmd-stack next
    cmd-stack next
    assert equal $env.cmd-stack.index 1

    cmd-stack prev
    assert equal $env.cmd-stack.index 0

    cmd-stack push 'c'
    assert equal $env.cmd-stack.stack ['a' 'b' 'c']
}

@test
def "push takes a list from the pipeline" [] {
    ['a'] | cmd-stack init --quiet
    ['b' '  ' 'c'] | cmd-stack push

    assert equal $env.cmd-stack.stack ['a' 'b' 'c']
}

@test
def "load skips the description block and starts at the first command" [] {
    let dir = stacks-folder
    let file = $dir | path join 'deploy.nu'

    $stack_text | save $file
    cmd-stack load deploy

    assert equal $env.cmd-stack {
        index: -1
        stack: ['ls' "# where am I\npwd" 'print done']
        source: $file
    }
    rm --recursive $dir
}

@test
def "load takes a path outside the stacks folder" [] {
    let dir = stacks-folder
    let file = mktemp --tmpdir elsewhere-XXXXXX.nu

    "ls\n\npwd\n" | save --force $file
    cmd-stack load $file

    assert equal $env.cmd-stack.stack ['ls' 'pwd']
    rm --recursive $dir $file
}

@test
def "a show of a loaded command is reported" [] {
    let dir = stacks-folder
    $env.ZELLIJ_PANE_ID = '7'

    $stack_text | save ($dir | path join 'deploy.nu')
    cmd-stack load deploy
    cmd-stack next
    cmd-stack next

    assert equal (shown $dir | select index command pane) [
        {index: 0 command: 'ls' pane: '7'}
        {index: 1 command: "# where am I\npwd" pane: '7'}
    ]
    rm --recursive $dir
}

@test
def "a show from init is not reported" [] {
    let dir = stacks-folder

    ['a'] | cmd-stack init --quiet
    cmd-stack next

    assert equal ($dir | path join shown.jsonl | path exists) false
    rm --recursive $dir
}

@test
def "completion lists the stacks newest first with their description" [] {
    let dir = stacks-folder

    "ls\n" | save ($dir | path join 'old.nu')
    # Why sleep, not `touch --date`: that flag is GNU only
    sleep 50ms
    $stack_text | save ($dir | path join 'new.nu')
    '' | save ($dir | path join shown.jsonl)

    let got = 'cmd-stack load ' | commandline complete --detailed

    assert equal ($got | get value) ['new' 'old']
    assert str contains ($got | first | get description) '3 commands'
    assert str contains ($got | first | get description) 'deploy the thing'
    rm --recursive $dir
}

@test
def "runs joins the last show with the next history row of its session" [] {
    let dir = stacks-folder
    let stack = $dir | path join 'deploy.nu'
    let other = $dir | path join 'other.nu'
    let db = $dir | path join history.sqlite3
    let at = '2026-11-04T00:00:00+00:00'

    "ls\n\npwd\n\nwhoami\n" | save $stack
    "date now\n" | save $other
    # `ls` is scrolled past to `pwd`, which runs as row 11; then `whoami` runs as row 12.
    # The show of `other.nu` runs as row 13 and does not belong to `deploy`.
    [
        {stack: $stack index: 0 command: 'ls' pane: '7' nu_session: 5 history_id: 10 at: $at}
        {stack: $stack index: 1 command: 'pwd' pane: '7' nu_session: 5 history_id: 10 at: $at}
        {stack: $stack index: 2 command: 'whoami' pane: '7' nu_session: 5 history_id: 11 at: $at}
        {stack: $other index: 0 command: 'date now' pane: '7' nu_session: 5 history_id: 12 at: $at}
    ]
    | each { to json --raw }
    | str join "\n"
    | save ($dir | path join shown.jsonl)

    [
        [id command_line session_id exit_status duration_ms];
        [10 'before' 5 0 1]
        [11 'pwd' 5 1 30]
        [12 'whoami' 5 0 20]
        [13 'date now' 5 0 5]
    ]
    | into sqlite $db --table-name history

    let got = cmd-stack runs deploy --history-db $db

    assert equal ($got | select index command ran exit_status duration) [
        {index: 1 command: 'pwd' ran: 'pwd' exit_status: 1 duration: 30ms}
        {index: 2 command: 'whoami' ran: 'whoami' exit_status: 0 duration: 20ms}
    ]
    rm --recursive $dir
}
