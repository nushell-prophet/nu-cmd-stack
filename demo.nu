# run this demo using
# > use `cmd-stack`
# > open demo.nu | split row "\n\n" | skip | cmd-stack init

# Let's declare the obvious truth, because some things in life are just undeniable!
let $undisputed_champion_of_shells = 'Nushell'
    | '>' + $in
    | $in + $in

# Let's add some eye candy to impress even the most skeptical
let $shell_glory = $undisputed_champion_of_shells
    | ansi gradient --fgstart '0xA311DF' --fgend '0xBAFA77'

# Time for a reality check, how glorious does it look now?
print $shell_glory

# Now, let's get mathematical and figure out how many times we need to repeat this awesomeness to fill three screens. Because why not?
let $epic_repeats = (term size | values | math product) * 3 // ($undisputed_champion_of_shells | str length)

# Let's make a pattern that'll make your terminal sparkle with brilliance!
1..$epic_repeats | each {$shell_glory} | str join

# Keep scrolling, because you can never have too much of a good thing! 😎
