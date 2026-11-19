# Bashism: How to make bash scripts work in dash

Source: <https://mywiki.wooledge.org/Bashism>

This page is an attempt to list some of the most common bashisms, i.e. features not defined by POSIX (won't work in dash, or general `/bin/sh`). It probably won't be exhaustive. Note also we talk about "bashism" because this wiki is largely bash-centric but a number (almost all) of these extensions work in at least some other shells like ksh or zsh with perhaps some differences in the details, as most of Bash's scripting features are derived from ksh. POSIX has simply required a much smaller number of them.

## Syntax

|  | **Works in bash** | **Change to for dash** | **Comment** |
|----|----|----|----|
| defining functions | `function f { echo hello world; }`<br>`function f() { echo hello world; }` | `f() { echo hello world; }` | "function" is not defined by POSIX, only "name ()" is. The `function f {...}` syntax originated in `ksh` (and predates the Bourne syntax). In ksh both forms are present, but in the AT&T implementations, functions defined with "function" work slightly differently. `zsh` also supports both syntax without distinction. |
| case | `;;&` `;&` etc | None. Duplicate the case (use a function to avoid code duplication, or an alias to let the shell expand the whole segment as it parses the script) | `;;&` `;&` in bash4 is not defined by POSIX. AT&T ksh (since [ksh88e](http://www.in-ulm.de/~mascheck/various/shells/ksh_versions.html), where it originated), MirBSD ksh (since [R40](http://www.mirbsd.org/cvs.cgi/src/bin/mksh/syn.c.diff?r1=1.64;r2=1.65;f=h)) and zsh (since 3.1.2) have `;&` but not `;;&` |
| numeric C-like for loop | `for ((i=0; i<3; i++)); do`<br>` printf '%s\n' "$i"`<br>`done` | `i=0`<br>`while [ "$i" -lt 3 ]; do`<br>` printf '%s\n' "$i"`<br>` i=$((i+1))`<br>`done` | This syntax is not defined by POSIX. Originated in ksh93; present in zsh. |
| expand sequences | `echo $'hello\tworld'` | `printf "hello\tworld\n"` | [Standardized in POSIX.1-2024](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html#tag_19_02_04) (albeit with fewer escape sequences than Bash supports). Originated in ksh93; available (with variations) in zsh, mksh, FreeBSD sh, and Busybox sh. |
| extended glob | `+( )` `@( )` `!( )` `*( )` | not always possible, sometimes you can use several globs, sometimes you can use find(1) | Not defined by POSIX. Originated in ksh; supported by zsh with an option like bash. |
| select | `select` | some ideas: implement the menu yourself, use a command like dialog | Not defined by POSIX. Originated in ksh; present in zsh. |
| file slurp | `$(< file)` | `$(cat file)` | Or read the file [line by line](https://mywiki.wooledge.org/BashFAQ/001). |

## Expansions

- Brace Expansion, eg `{a,b,c}` or `{1..10}` is not defined by POSIX. Both forms are present in zsh, ksh93, yash (with an option) and the first form in older ksh and mksh. The first one originated in csh, the second in zsh.

- The `<( )` and `>( )` process substitutions are not defined by POSIX, but can be simulated with FIFOs: instead of `foo <(bar)`, write `mkfifo /tmp/foo_fifo; bar > /tmp/foo_fifo & foo /tmp/foo_fifo` (this is basically how process substitution is implemented on OSes that don't have a mechanism like `/dev/fd/` to refer to unnamed pipes with filenames). Originated in ksh86, also present in zsh.

## Parameter Expansions

List of expansions not defined by POSIX:

- `${name:n:l}` -- You can use `$(expr "x$name" : "x.\{0,$n\}\(.\{0,$l\}\)")`. This originated in ksh93 and is also present in zsh, mksh and busybox sh.

- `${name/foo/bar}` -- you can use `$(printf '%s\n' "$name" | sed 's/foo/bar/')`, after changing shell patterns to regular expressions. This originated in ksh93 and is also present in mksh, and zsh, but variation in behaviour and glob pattern syntax between the three.

- `${!name}` -- bash-specific; it is possible to use `eval` to achieve similar effects, but it requires great attention to detail; see [BashFAQ/006](https://mywiki.wooledge.org/BashFAQ/006).

- The behavior of the `#`, `##`, `%`, and `%%` operators are unspecified by POSIX and the ksh88 manual when used together with the `@` or `*` parameters. Dash applies the trimming to the flattened result. mksh/pdksh treats it as a bad expansion.

Note that using `$( )` has the side-effect of removing trailing newlines from the results. See [CommandSubstitution](https://mywiki.wooledge.org/CommandSubstitution) for workarounds.

## Arrays

[Arrays](https://mywiki.wooledge.org/BashFAQ/005) are not defined by POSIX (but are present in ksh); there is no easy general workaround for arrays. Here are some hints:

- The positional parameters are a kind of array (only one array):

``` sh
# Build a command dynamically. See BashFAQ/050
set -- 'mycommand' 'needs some complex' 'args'
"$@"
#access the i'th param
set -- one two three
i=2
eval "var=\${$i}" # i should be controlled by the script at all times. If influenced by side-effects like user input, robust validation is required.
printf '%s\n' "$var"
```

- use `IFS` and `set -o noglob` (or `set -f` for short).

- `eval` is powerful but easy to misuse in dangerous ways. See [Eval command and security issues](https://mywiki.wooledge.org/BashFAQ/048).

## Conditionals

|  | **Works in bash** | **Change to for dash** | **Comment** |
|----|----|----|----|
| simple test | `[[` | use \[ and use double quotes around the expansions `[ "$var" = foo ] && [ "$n" -gt 3 ]`, do **not** use the binary `-a` and `-o` operators | `[[...]]` is not defined by POSIX, originated in ksh and is also present in zsh |
| pattern matching | `[[ foo == *glov ]]` | use `case` (or `awk`, `expr`, `grep`) | see [BashFAQ/041](https://mywiki.wooledge.org/BashFAQ/041) |
| equality with test | `==` | use `=` instead | only `=` is defined by POSIX |
| compare lexicographically. | `<` `>` | no change | [Standardized in POSIX.1-2024](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/test.html); available in dash, ksh, yash, and zsh. For other shells, see note below for possible workarounds. |
| compare modification times | `[[ file1 -nt file2 ]]` or `-ot` | `[ "$(find 'file1' -prune -newer 'file2')" ]` or `[ "file1" -nt "file2" ]` | [Standardized in POSIX.1-2024](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/test.html); available in dash, ksh, yash, and zsh. (In the `find`-based alternative, `-prune` is required to avoid recursion). Beware of variations in behaviour when symlinks are involved. |
| check if 2 files are the same hardlink | `[[ file1 -ef file2 ]]` | `[ "file1" -ef "file2" ]` | [Standardized in POSIX.1-2024](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/test.html); available in dash, ksh, yash, and zsh. |
| `(( ))` | `(( ))` (without the `$`) acts like a command on its own | For simple comparison: `[ -lt ] (and -ne -gt -ge)`. To assign a variable `var=$((3+1))`. For full functionality, use `[ "$(( (i+=2) < 5 && a > 3))" -ne 0 ]`. | present in ksh (where it originated) and zsh |

Note: several standard POSIX utilities can be used for lexical comparisons. The examples below return a true (zero) exit status if the content of `$a` sorts before `$b`.

- `awk -- 'BEGIN { exit !(ARGV[1] "" < "" ARGV[2]) }' "$a" "$b"`

- `expr "x$a" "<" "x$b" >/dev/null`

- If the variables don't contain newline characters: `printf "%s\n" "x$a" "x$b" | sort -C` (also returns true if `$a` and `$b` are equal)

## Arithmetic

See [Arithmetic Precision and Operators](http://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap01.html#tag_17_01_02_01) and [Arithmetic expansion](http://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_06_04) for supported and required math expression features.

|  | **Works in bash** | **Change to for dash** | **Comment** |
|----|----|----|----|
| pre/post increment/decrement | `++` `--` | `i=$((i+1))` or `: "$((i+=1))"` |  |
| comma operator | `,` | `: "$((...))"; cmd "$((...))"` | The comma operator is *widely* supported by almost everything except dash and yash -- even posh and Busybox. In ksh93 however, it conflicts with the decimal radix in locales where it's used in floating points instead of period |
| exponentiation | `**` |  | `**` is the only bash arithmetic operator that is not a standard C or C++ operator. ksh93 can use `pow(x, y)`. The `**` operator is supported by at least bash, zsh, ksh93, and busybox, but not by dash or mksh. |
|  | `let` or `((...))` | `[ "$((...))" -ne 0 ]` | Because of the above comma restriction, `let` can't be simulated exactly without a loop. |

## Redirections

|  | **Works in bash** | **Change to for dash** | **Comment** |
|----|----|----|----|
| redirect both stdout and stderr | `>&` or `&>` | `command > file 2>&1` | \- |
|  | `\|&` (bash4) | `command 2>&1 \| othercommand` | Conflicts with ksh. Not recommended, even in Bash. Just use `2>&1`. |
| duplicate and close | `m>&n-` or `m<&n-` | `m>&n n>&-` | not defined by POSIX |
| herestring | `<<<"string"` | `echo \| command`, or a here document to avoid a subshell (`<<EOF`) | \- |

## Builtins

- `echo -n` or `-e` -- POSIX doesn't define any options, and furthermore allows `echo -e` to be the default behavior. Instead use `printf "%s\n"` (for normal echo) or `printf "%b\n"` (for `echo -e`); leave off the `\n` to simulate `echo -n`.

- `printf -v` is not defined by POSIX, and only Bash and Zsh support it. The `%q` format is not defined by POSIX but supported by ksh93, zsh, GNU printf and Bash (though with variations). The a, A, e, E, f, F, g, and G formats are not required by POSIX for `printf(1)`, but dash appears to support `%f`, `%e`, `%E`, `%g`, and `%G`. `%()T` is only supported by ksh93 and Bash though with variations.

- `read` -- the only option defined by POSIX is `-r`; ksh and zsh have different sets of options that only partially overlap with bash.

- `shopt`, and therefore all the options it provides (`extglob`, `nullglob`, `dotglob`, etc.) are not defined by POSIX and are bash-specific

- `local` -- there is no POSIX equivalent. You can use `$funcname_varname` to reduce the likelihood of conflicts, but even that is not enough for recursive functions. You can ensure that recursive calls occur in subshell environments (so there is a "local" copy of all variables), or pass all "local variables" as parameters (because the positional parameters `$@`, `$1`, `$2`, etc are truly local). dash explicitly supports `local` as a non-Posix extension; ksh uses `typeset` instead, which works like bash's `declare`. `local` is mandated by the LSB and Debian policy specifications, though only the `local varname` (not `local var=value`) syntax is specified. An implementation of a variable stack for POSIX shells can be found [there](https://github.com/stephane-chazelas/misc-scripts/blob/master/locvar.sh).

## Special Variables

|  | **Works in bash** | **Change to for dash** | **Comment** |
|----|----|----|----|
| keep track of the times | `SECONDS` | `before=$(date +%s) ....seconds=$(( $(date +%s) - before))` | `date +%s` is not POSIX; see [this faq for more info](https://mywiki.wooledge.org/BashFAQ/070). Present in ksh and zsh |
| Generate a random number | `RANDOM` | `random=$(awk 'BEGIN{srand(); printf "%d\n",(rand()*256)}')` gives a number between 0 and 256<br>`random=$(LC_ALL=C od -vAn -N1 -t u1 /dev/urandom \| tr -d '[:space:]')` gives a timer-independent number between 0 and 256<br>`random=$(LC_ALL=C od -vAn -N2 -t u2 /dev/urandom \| tr -d '[:space:]')` gives a timer-independent number between 0 and 65535 | Be sure to learn what `srand()` and `rand()` do, ie this method fails if you call `awk` several times rapidly. Instead generate all the numbers you need inside `awk`. Some systems also provide /dev/random and /dev/urandom , but this is not specified by the POSIX standard. ksh and zsh have `RANDOM` |
| Get the status of all the commands in a pipeline | `PIPESTATUS` | Simplest solution:<br>`mkfifo fifo; command2 <fifo & command1 >fifo; echo "$?"`<br>see [NamedPipes](https://mywiki.wooledge.org/NamedPipes) | bash-specific; see [this faq](http://shell.cfajohnson.com/cus-faq-2.html#Q11) |
| Get the name of all / the current function name(s) | `FUNCNAME` | ?? | bash-specific see [stackoverflow question](http://stackoverflow.com/questions/2630812/get-a-list-of-function-names-in-a-shell-script) |

## More

- [The bash manual](http://www.gnu.org/software/bash/manual/html_node/Bash-POSIX-Mode.html#Bash-POSIX-Mode) has a list of the differences between bash running in POSIX mode and a normal bash.\
  **Note**: invoking bash in POSIX mode is only guaranteed to run a shell written according to the POSIX specification. It *doesn't* mean that it will fail if you use bashisms in your scripts.

- There is a handy perl script checkbashisms which is part of the debian devscripts package which can help point out bashisms in a particular script.

- <https://wiki.ubuntu.com/DashAsBinSh> The Ubuntu wiki also has a page that describes the differences

- [Rich's sh tricks](http://www.etalabs.net/sh_tricks.html) has some clever yet surprisingly powerful hacks for dealing with the limitations of the POSIX shell.
