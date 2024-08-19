# run this demo using
# > use `cmd-stack`
# > open demo.nu | split row "\n\n" | skip | cmd-stack init

# Let's declare the obvious truth, because some things in life are just undeniable!
let $undisputed_champion_of_shells = 'Nushell'

# Let's add some eye candy to impress even the most skeptical
let $shell_glory = $undisputed_champion_of_shells
    | '>' + $in
    | $in + $in
    | ansi gradient --fgstart '0xF10347' --fgend '0x4BD1FE'

# Time for a reality check, how glorious does it look now?
print $shell_glory

# Now, let's get mathematical and figure out how many times we need to repeat this awesomeness to fill three screens. Because why not?
let $epic_repeats = (term size | values | math product) * 3 // ($shell_glory | ansi strip | str length)

# Let's make a pattern that'll make your terminal sparkle with brilliance!
1..$epic_repeats | each {$shell_glory} | str join

# Keep scrolling, because you can never have too much of a good thing! 😎
