# Coreutils Gotchas

Source: [https://www.pixelbeat.org/docs/coreutils-gotchas.html](https://www.pixelbeat.org/docs/coreutils-gotchas.html)

Author: Pádraig Brady (Pixelbeat).

License: [Creative Commons Attribution-ShareAlike 3.0 Unported](http://creativecommons.org/licenses/by-sa/3.0/).

Converted from HTML to Markdown; original wording and examples preserved.

We make very careful considerations about the interface and operation
of the GNU coreutils, but unfortunately due to backwards compatibility
reasons, some behaviours or [defaults](https://www.pixelbeat.org/docs/power_of_the_default.html)
of these utilities can be confusing.

This information will continue to be updated and overlaps somewhat with the [coreutils FAQ](http://www.gnu.org/software/coreutils/faq/coreutils-faq.html),
with this list focusing on less frequent potential issues.

## chmod

chmod -R is redundant and tricky.
If for example you copy a dir from VFAT and want to turn off executable bits on files
using `chmod -R 644`,
that will fail to recurse as it removes the executable bits from dirs.
This is achievable in various ways:

- `find -type f -print0 | xargs -r0 chmod 644` # Traditional method
- `find -type f -exec chmod 644 {} +` # Newer POSIX equivalent
- `chmod -R a-x,a+X` # Using GNU extensions to in-tool recursion

## cut

cut doesn't work with fields separated by arbitrary whitespace.
It's often better to use `awk` or
even `join -a1 -o1.$field $file /dev/null`

cut -s only suppresses lines without delimiters.
Therefore if you have a line with a missing field
but it does contain some delimiters, a blank line is output

Similarly, if you want to output a blank line when there are no delimiters
one needs to append a delimiter like:

```
printf '%s\n' a:b c d:e | sed '/:/!s/$/:/' | cut -d: -f2-
```

## date

There are many ambiguities with [date input formats](https://www.gnu.org/software/coreutils/manual/html_node/Date-input-formats.html),
but time zone specifications are especially confusing due to the inadequate error reporting in the POSIX timezone APIs.
Consider for example:

```
TZ=Asia/Tokyo date
Wed 09 Jul 2025 04:26:34 JST

$ TZ=JST date # wrong
Tue 08 Jul 2025 19:26:48 JST
```

JST is output, but for the second case it's just UTC.
The main advice here is to use location based inputs like the first example above.
This also applies to touch which can take a date as input.
Note the `date --debug` option is very useful to detail
how input dates are being processed.
For more details see [Linux timezone gotchas](https://www.pixelbeat.org/docs/linux_timezones/).

## dd

dd *iflag=fullblock* is usually what you want
because when reading from a fifo/pipe you often get a short read,
which means you get too little data if you specify "*count*",
or too much data if you specify "*sync*". For example:

```
$ dd status=none bs=1 count=512 if=/dev/zero |
  dd status=none count=1 bs=512 | wc -c
78
```

Note we do warn in certain cases since version 8.10, but not with count=1 above
as short reads are often used with count=1 as an idiom to "consume available data",
though perhaps `dd iflag=nonblock` would be a more
direct and general way to do that?

dd *conv=noerror* really also needs *conv=sync*
so that if reading from failing disk,
one gets correctly aligned data, with unreadable bits replaced with NULs.
Note if there is a read error anywhere in a block,
the whole block will be discarded. So one needs
to balance between speed (bigger) and minimized data loss (smaller).
This is simpler and more dynamic in a more dedicated tool
like *ddrescue*.

dd *skip=0x100* doesn't skip anything
as the "0x" prefix is treated as a zero multiplier.
coreutils >= 8.26 will warn about this at least,
suggesting to use "00x" if that really was the intention.

## df

For full portability the *-P* option is needed
when parsing the output from df. Line wrapping is avoided, though
df will no longer wrap lines since version 8.11 (Apr 2011) to help
avoid this gotcha. Also if one needs to parse the header,
the *-P* option will use more standardised (but ambiguous) wording.
See also the [Block size](https://www.pixelbeat.org/docs/coreutils-gotchas.html#units) issue.

## du

If two or more hard links point to the same file, only one of the
hard links is counted. The FILE argument order affects which links are
counted, and changing the argument order may change the numbers that
*du* outputs. Note this also impacts specified directories which is confusing:

```
$ cd git/coreutils
$ du -s ./ ./tests
593120  ./
$ du -s ./tests ./  # depth first gets items listed (though counted independently)
10036   ./tests
583084  ./
# Note order is significant even with implicit independence
$ du -s --separate-dirs ./tests ./
128     ./tests
16268   ./
$ du -s --separate-dirs ./ ./tests
16268   ./
```

Note du doesn't handle [reflinked files](https://www.pixelbeat.org/docs/unix_links.html) specially,
and thus will count all instances of a reflinked file.

## echo

*echo* is non portable and its behaviour diverges between
systems and shell builtins etc. One should really consider using
[printf](http://www.gnu.org/software/coreutils/printf) instead.
This shell session illustrates some inconsistencies.
Where you see *env* being used, that is selecting the coreutils
standalone version:

```
$ echo -e -n # outputs nothing
$ echo -n -e
$ echo -- -n # option terminator outputted
-- -n
$ POSIXLY_CORRECT=1 env echo -e -n
-e -n
$ POSIXLY_CORRECT=1 env echo -n -e # no output either ‽
```

## expr

The exit status of expr is a confusing gotcha.
POSIX states that exit status of 1 is used if "the expression evaluates to null or zero",
which you can see in these examples:

```
$ expr 2 - 1; echo $?
1
0

$ expr 2 - 2; echo $?
0
1

$ expr substr 01 1 1; echo $?
0
1

$ expr ' ' : '^ *$'; echo $?
1
0

$ expr '' : '^ *$'; echo $?
0
1

# number of matched characters returned
$ expr 0 : '[0-9]$'; echo $?
1
0

# actual matched characters returned
$ expr 0 : '\([0-9]\)$'; echo $?
0
1
```

The string matching above is especially confusing, though
does conform to POSIX, and is consistent across solaris, FreeBSD and GNU utils.

As for changing the behaviour, it's probably not possible due to
backwards compatibility issues. For example the '^..\*$' case
would need to change the handling of the '\*' in the expression,
which would break a script like:

```
printf '%s\n' 1 2 '' 3 |
while read line; do
  expr "$line" : '^[0-9]*$' >/dev/null || break # at first blank line
  echo process "$line"
done
```

Note, using a leading ^ in the expression is redundant and non portable.

## ls

ls -lrt will also reverse sort names for files
with matching timestamps (common in /dev/ and /proc/ etc.)
This is as per POSIX but probably not what the user wanted.
There is no way to reverse by time and have non reversed name sorting.

## ln

`ln -nsf` is needed to update symlinks,
though note that this will overwrite existing files,
and cause links to be created within existing directories.

## mkdir

`mkdir -p --mode=...` only applies the mode to the
right-most directory. Any parent directories are created with
'u+wx' modified by umask. If you want to control the mode for all created dirs,
you can use a umask like

```
(umask u=rwx,go=rx; mkdir -p dir1/dir2/dir3)
```

Note that the user 'wx' bits can not be cleared for parent dirs.
Note also that special mode bits like setuid are not set atomically,
either with --mode on the right-most directory, or a subsequent chmod required
for created parent directories. Note also to be careful with [chmod -R](https://www.pixelbeat.org/docs/coreutils-gotchas.html#chmod)  
  
If changing the umask before invoking mkdir is not that easy - maybe
because not called via a shell -, then an alternative to the above
umask method is to specify each of the target directories separately,
e.g.:

```
mkdir -pm 0700  dir1  dir1/dir2  dir1/dir2/dir3
```

But it is important to know that 'mkdir' does not adjust the permission
bits if any of those directories already existed.
If you do want to ensure a directory hierarchy with particular permissions
one can use the `install` command instead like:

```
install -dm 0700  dir1  dir1/dir2  dir1/dir2/dir3
```

## \*sum

The checksum utilities like md5sum, sha1sum etc. add backslashes to the output names
if those names contain '\n' or '\' characters. Also '\*' is added to the output
where O\_BINARY is significant (CYGWIN). Therefore automatic processing of these
utilities require one to [unescape](https://github.com/pixelb/fslint/blame/4b931d09/fslint/findup#L103-L117) first,
or to use --zero to NUL separate entries, where escaping is not requred.

## nl

`nl` defaults to `-d '\:'` by default.
Therefore any lines that contain only `'\:'`, `'\:\:'`
or `'\:\:\:'` will reset numbering.
If you want to number lines irrespective on content then you need to specify `-d ''`,
or alternatively use the less flexible `cat -n` option.

## pr

The following is from [Doug McIlroy](http://comments.pixelbeat.org/docs/coreutils-gotchas.html?all=1#comment-5149890158002176):
Multi-column pr, that is `pr -COLUMN` where COLUMN>=2, implicitly turns on options -e
(expand input **tab characters** to spaces) and -i (greedily convert runs of output space characters to **tabs**).
Output tabs may appear where no input tabs existed; further processing of the output may be fraught.
This pipeline will eliminate all output tabs: `pr -COLUMN | pr -e -t`.

The -ein short options take an optional character as their first parameter.
This flexibility can be confusing. E.g. sometimes users may use an equals with
a short option, like -e=4. But that's accepted, and sets the TAB character to "="
as well as changing the tab width to 4.

## rm

`rm -rf` does not mean "delete as much as possible". It only avoids prompts.
For example with a non writeable dir, you will not be able
to remove any contents. Therefore this is sometimes necessary to:

```
find "$dir" -depth -type d -exec chmod +wx {} + && rm -rf "$dir"
```

## sort

A very common issue encountered is with the default ordering of the *sort* utility.
Usually what is required is a simple byte comparison, though by default the collation
order of the current locale is used. To use the simple comparison logic you can
`LC_ALL=C sort ...` as
[detailed in the FAQ](http://www.gnu.org/software/coreutils/faq/coreutils-faq.html#Sort-does-not-sort-in-normal-order_0021).

### equal comparisons

As well as being slower, the locale based ordering can often be surprising.
For example some character representations,
like the full width forms of latin numbers, compare equal to each other.

```
$ printf '%s\n' ２ １ | ltrace -e strcoll sort
sort->strcoll("\357\274\222", "\357\274\221") = 0
２
１

$ printf '%s\n' ２ １ | sort -u
２
```

The equal comparison issue with --unique can even impact in
the "C" locale, for example with *--numeric-sort* dropping items unexpectedly.
Note this example also demonstrates that --unique implies --stable,
to select the first encountered item in the matching set.

```
$ printf "%s\n" 1 zero 0 .0 | sort -nu
zero
1
```

### i18n patch issues

Related to locale ordering, there is the [i18n patch](https://www.pixelbeat.org/docs/coreutils_i18n/)
on Fedora/RHEL/SUSE which has its own issues. Note disabling the locale specific
handling as described above effectively avoids these issues.

Example 1: leading space are mishandled with --human-numeric-sort:

```
$ printf ' %s\n' 4.0K 1.7K | sort -s -h
 4.0K
 1.7K
```

Example 2: case folding results in incorrect ordering:

```
$ printf '%s\n' Dániel Dylan | sort
Dániel
Dylan

$ printf '%s\n' Dániel Dylan | sort -f
Dylan
Dániel
```

### field handling

Fields specified with *-k* are separated by default by runs of blank characters (space and tab),
and by default the blank characters preceding a field are *included* in the comparison,
which depending on your locale could be significant to the sorting order. This is confusing enough
on its own, but is compounded with the *--field-separator* and *--ignore-leading-blanks* options.
Ignoring leading blanks (-b) is particularly confusing, because...

- If specified like -k1,1b it only applies to end char count
- If specified like -b -k1,1.2n -k2,2 then it's not used for the first field
- If specified like -n -k1,1b -k2,2 then -n not used for the first field
- In general you usually want -b with -k, but it's off by default
- sort -k1,1.endpos only works for fixed width fields (spans multiple fields)
- Empty fields are problematic

Also precisely specifying a particular field, requires both the start *and end*
fields specified. I.E. to sort on field 2 you use -k2*,2*.

These field delineation issues along with others are so confusing,
that the [sort --debug](https://www.pixelbeat.org/patches/coreutils/sort-debug/) option was added
in version 8.6 to highlight the matching extent and other consequences of the various options.

### --random-sort

`sort -R` does randomize the input similarly
to the shuf command, but also ensures that matching keys are grouped together.
shuf also provides optimizations when outputting a subset of the input.

### --unique

`sort -u` only operates on the part of the line being compared,
rather than the whole line. If you want to only suppress full duplicate lines,
then it's probably best to [pipe the output to uniq](https://github.com/coreutils/coreutils/commit/55fe28e3e).

## split

`split` produces file names that may be surprising,
as it defaults to a two letter suffix for initial files, but
to support an arbitrary number of files, has a feature to widen the letters in
the output file names as needed. The widening scheme ensures file names are sorted correctly
when using standard shell sorting, when subsequently listing or
concatenating the resultant files. For example:

```
$ seq 1000 | split -l 1 - foo_
$ ls foo_*
...
foo_yy
foo_yz
foo_zaaa
foo_zaab
...
```

`split` behaves the same with the
`--numeric-suffixes/-d` option, which could
lead to unexpected numeric sequences. This was done again to ease sorting
of the output (which is usually not inspected by humans for large sequences),
but mainly for backwards compatibility with existing concatenation scripts
that use standard sorting.

```
$ seq 1000 | split -l 10 -d - bar_
$ ls bar_*
...
bar_88
bar_89
bar_9000
bar_9001
...
```

The recommended solution is to specify a
`-a/--suffix-length` parameter
which still allows for standard ordering at the shell,
but with more natural numbers:

```
$ seq 1000 | split -a5 -l 10 -d - baz_
$ ls baz_*
baz_00000
baz_00001
...
baz_00098
baz_00099
```

## tac

tac like [wc](https://www.pixelbeat.org/docs/coreutils-gotchas.html#wc) has issues dealing with files without
a last '\n' character.

```
$ printf "1\n2" | tac
21
```

## tail

tail -F is probably what you want rather than -f
as the latter doesn't follow log rotations etc.

tail -n **+**NUM is inconsistent with all other head and tail -n formats,
in that it specifies the index to start output at, rather than a number of items to skip or include.
I.e. +NUM is 1 more than you might expect. For example to omit the first line one would use `tail -n +2`.
Similarly with -c, if you wanted to skip a particular number of **bytes**, you need to add 1
to the exact number of bytes you want to skip. For example skipping the first 2GiB of a file
could be achieved with `tail -c +$(($(numfmt --from=iec 2G) + 1))`,
though using dd for this is probably more appropriate.

## tee

tee by default will exit immediately upon receiving
[SIGPIPE](https://www.pixelbeat.org/programming/sigpipe_handling.html)
to be POSIX compliant and to support applications like
`yes | tee log | timeout process`.
Now this is problematic in the presence of "early close" pipes,
often seen when combining tee with bash >(process substitutions).
Starting with coreutils 8.24 (Jul 2015), tee has the new -p, --output-error
option to control the operation in such cases.

```
$ seq 100000 | tee >(head -n1) > >(tail -n1)
1
14139

$ seq 100000 | tee -p >(head -n1) > >(tail -n1)
1
100000
```

## test

The mode of operation of test depends on the number of arguments.
Therefore you will not get an expected error in cases like
`test -s $file || echo no data >&2`,
if "$file" is empty or unset. That's because test(1) will then
be operating in string testing mode, which will return success
due to "-s" being interpreted as a true expression.
Instead ensure the variable is appropriately quoted to avoid such issues:
`test -s "$file" || echo no data >&2`.

## tr

Arguments to tr should be appropriately quoted so they're not
processed by the shell. This is especially problematic as usually
quoting is not required, but depending on the contents of the current directory,
globbing may induce unexpected behavior.
Consider `tr [:lower:] [:upper:]`, which will usually
work fine, but once there is a file named `:` etc.
in the current directory, then tr will be given `tr : :`
which is a silent no-op. To protect against this one needs to appropriately quote
e.g., `tr '[:lower:]' '[:upper:]'`.

## uniq

The uniq `-f` option to skip fields,
has an unusual definition of a field. Specifically a field is an optional run
of blank characters (space or tab) followed by a run of non blank chars.
This implies that -f1 to skip the first field, will skip any
leading blank characters and then non blank characters.
It also means that the leading space is still part of the comparison
of each field, which will be significant (problematic) in files
with a variable amount of blanks separating fields.
`tr -s '[:blank:]'` may be useful to
squash runs of blanks to avoid this issue, before processing with uniq.

## wc

`wc -l` on a file in which the last line
doesn't end with '\n' character will return a value of one-less than
might be expected as wc is standardised to just count '\n' characters.
POSIX in fact doesn't consider a file without a '\n' as the last character
to be a text file at all. Also by only counting '\n' characters results
in consistent counts whether counting concatenated files, or
totaling individual files.

```
$ printf "hello\nworld" | wc -l
1
```

`wc -L` counts the maximum *display* width for a line,
considering only valid, printable characters, but not terminal control codes.

```
# invalid UTF-8 sequence not counted:
$ printf "\xe2\xf2\xa5" | wc -L
0

# unprintable characters even in the C locale are not counted:
$ printf "\xe2\x99\xa5" | LC_ALL=C wc -L
0

# Bytes can be counted using sed:
$ printf "\xe2\x99\xa5" | LC_ALL=C sed 's/././g' | wc -L
3

# Terminal control chars are not handled specially:
$ printf '\x1b[33mf\bred\x1b[m\n' | tee /dev/tty | wc -L
red
10
```

## Unit representations

The *df*, *du*, *ls*
[--block-size](https://www.gnu.org/software/coreutils/manual/html_node/Block-size.html)
option is unusual in that appending a **B** to the unit, changes it *from* binary to decimal.
I.E. KB means 1000, while K means 1024.

In general the units representations in coreutils are unfortunate,
but an accident of history.
POSIX species 'k' and 'b' to mean 1024 and 512 respectively.
Standards wise 'k' should really mean 1000 and 'K' 1024.
Then extending from that we now have (which we can't change for compatibility reasons):

- k=K=kiB=KiB=1024
- kb=KB=1000
- M=MiB=1024²
- MB=1000²
- ...

Note there is new flexibility to consider when controlling the
output of numeric units, by leveraging the [numfmt](https://www.pixelbeat.org/docs/numfmt.html)
utility. For example to control the output of du you could define
a function like:

```
 du() { env du -B1 "$@" | numfmt --to=iec-i --suffix=B; } 
```

[©](http://creativecommons.org/licenses/by-sa/3.0/) Nov 29 2015
