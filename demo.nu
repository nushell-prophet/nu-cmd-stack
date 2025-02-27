# Because who needs boring demos, anyway?
# run this demo using
# > use `cmd-stack`
# > open demo.nu | split row "\n\n" | skip | cmd-stack init

# First things first, let's grab the best shell
let $best_shell = 'Nushell'

# But a plain name is a bit, well, plain. Let's add some pizazz!
let $blazing_glory = $best_shell
| '>' + $in + '>' + $in
| ansi gradient --fgstart '0xF10347' --fgend '0x4BD1FE'

# Time to admire our masterpiece!
print $blazing_glory

# But how much of this beauty is enough? Enough to fill 3 WHOLE screens, that's how much!
# (Although some might argue that's never enough...)
let $screens = 3
let $searing_repeats = (term size | $in.columns * $in.rows) * $screens // ($blazing_glory | ansi strip | str length --grapheme-clusters)

# Now, let's unleash the glorious Nushell spam!
# Warning: May cause terminal overload and feelings of pure joy.
1..$searing_repeats | each { $blazing_glory } | str join
