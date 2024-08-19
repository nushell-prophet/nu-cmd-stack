# Because who needs boring demos, anyway?
# run this demo using
# > use `cmd-stack`
# > open demo.nu | split row "\n\n" | skip | cmd-stack init

# First things first, let's grab the best shell
let $best_shell = 'Nushell'

# Time to turn up the heat and make even the skeptics sweat!
let $blazing_glory = $best_shell
    | '>' + $in + '>' + $in
    | ansi gradient --fgstart '0xF10347' --fgend '0x4BD1FE'

# Ready to see how it burns? Let’s check it out!
print $blazing_glory

# Now, let’s crunch the numbers and find out how many times we need to repeat this inferno to scorch three screens!
let $searing_repeats = (term size | values | math product) // ($blazing_glory | ansi strip | str length --grapheme-clusters)

# Let’s light up the terminal with a pattern that’ll leave you feeling the heat!
1..$searing_repeats | each {$blazing_glory} | str join

# Keep scrolling, and feel the burn! 🔥😎
