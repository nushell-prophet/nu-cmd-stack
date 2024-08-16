# Let's set the `best_shell` variable to some correct value
let best_shell = 'Nushell'

# Let's add some beauty
let $some_beauty = $'>($best_shell)' |  ansi gradient --fgstart '0x3719bd' --fgend '0xa9be52'

# Let's check how it now looks like
print $some_beauty

# Let's calculate how many times we should type it to fill 3 screens
let $times = (term size | values | math product) * 3 // ($best_shell | str length)

# Let's make a pattern!
1..$times | each {$some_beauty} | str join

# Scroll, it's cool:)
