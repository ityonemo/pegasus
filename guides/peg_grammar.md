# PEG Grammar Reference

This guide provides a complete reference for the PEG (Parsing Expression Grammar) syntax supported by Pegasus.

## Grammar Structure

A PEG grammar consists of one or more **definitions** (rules). Each definition has an **identifier** and an **expression**:

```peg
identifier <- expression
```

The first rule is typically the entry point, though in Pegasus you explicitly mark entry points with the `:parser` option.

## Identifiers

Rule names (identifiers) must start with a letter or underscore, followed by letters, digits, or underscores:

```peg
my_rule    <- ...
Rule2      <- ...
_private   <- ...
```

> #### Capitalized Identifiers {: .info}
>
> Capitalized identifiers like `MyRule` work but require special handling when
> calling from Elixir code. See the [Capitalized Identifiers](#capitalized-identifiers) section.

## Expressions

### Literals

Match exact strings using single or double quotes:

```peg
rule <- 'hello'
rule <- "world"
```

Both quote styles are equivalent. Use one when you need to include the other:

```peg
quoted <- "it's"
also   <- 'say "hello"'
```

### Character Classes

Match a single character from a set:

```peg
digit <- [0-9]
letter <- [a-zA-Z]
hex <- [0-9a-fA-F]
```

Combine multiple ranges and individual characters:

```peg
alphanum <- [a-zA-Z0-9_]
vowel <- [aeiouAEIOU]
```

#### Negated Classes

Match any character NOT in the set:

```peg
not_digit <- [^0-9]
not_quote <- [^"]
```

#### Special Characters in Classes

Use backslash escapes for special characters:

```peg
bracket <- [\[\]]        # matches [ or ]
hyphen <- [a\-z]         # matches a, -, or z (hyphen as literal)
backslash <- [\\]        # matches \
```

### Dot (Any Character)

Match any single character:

```peg
any <- .
```

This matches any character including newlines.

### Sequences

Match expressions in order:

```peg
hello_world <- 'hello' ' ' 'world'
```

All parts must match for the sequence to succeed.

### Ordered Choice

Try alternatives in order:

```peg
bool <- 'true' / 'false'
digit <- '0' / '1' / '2' / '3' / '4' / '5' / '6' / '7' / '8' / '9'
```

The first matching alternative wins. Unlike regular expressions, PEG choices are deterministic and ordered.

### Repetition

#### Zero or More (`*`)

```peg
digits <- [0-9]*
ws <- [ \t\n]*
```

#### One or More (`+`)

```peg
identifier <- [a-zA-Z] [a-zA-Z0-9]*
number <- [0-9]+
```

#### Optional (`?`)

```peg
signed_number <- '-'? [0-9]+
optional_semicolon <- ';'?
```

### Grouping

Use parentheses to group expressions:

```peg
term <- ('+' / '-') number
list <- item (',' item)*
```

Grouping is essential for combining operators:

```peg
# Without grouping: matches 'a' or ('b' followed by 'c')
wrong <- 'a' / 'b' 'c'

# With grouping: matches ('a' or 'b') followed by 'c'
right <- ('a' / 'b') 'c'
```

### Lookahead

#### Positive Lookahead (`&`)

Match only if the expression would match, but don't consume input:

```peg
# Match 'a' only if followed by 'b'
a_before_b <- 'a' &'b'
```

#### Negative Lookahead (`!`)

Match only if the expression would NOT match:

```peg
# Match any character except newline
not_newline <- !'\n' .

# Match identifier that isn't a keyword
identifier <- !keyword [a-zA-Z]+
keyword <- 'if' / 'else' / 'while'
```

### Extracted Groups (`<...>`)

Mark content for extraction:

```peg
quoted <- '"' <[^"]*> '"'
```

Extracted groups filter the result to include only the matched text, excluding surrounding syntax.

## Escape Sequences

Pegasus supports ANSI C escape sequences in literals and character classes:

| Escape | Meaning |
|--------|---------|
| `\a` | Bell (alert) |
| `\b` | Backspace |
| `\e` | Escape |
| `\f` | Form feed |
| `\n` | Newline |
| `\r` | Carriage return |
| `\t` | Horizontal tab |
| `\v` | Vertical tab |
| `\'` | Single quote |
| `\"` | Double quote |
| `\\` | Backslash |
| `\[` | Left bracket |
| `\]` | Right bracket |
| `\-` | Hyphen (in character classes) |

### Octal Escapes

Specify characters by octal code:

```peg
null <- '\0'
bell <- '\7'
tab <- '\11'
max <- '\377'
```

Octal escapes use 1-3 digits, with values from 0-377 (octal).

## Comments

Line comments start with `#`:

```peg
# This is a comment
rule <- 'hello'  # inline comment
```

## Operator Precedence

From highest to lowest precedence:

1. `()` - Grouping
2. `*`, `+`, `?` - Repetition
3. `&`, `!` - Lookahead
4. Sequence (implicit)
5. `/` - Choice

Example:

```peg
# This parses as: (a b*) / c
rule <- a b* / c

# Use grouping to change precedence:
rule <- a (b / c)*
```

> #### Capitalized Identifiers {: .info}
>
> Capitalized PEG identifiers like `Statement` or `Expression` work fine.
> Just remember to put a colon in front of them in the options keyword list,
> since capitalized names in Elixir are aliases:
>
>     Pegasus.parser_from_string("Foo <- 'foo'", Foo: [parser: :parse])
>
> Capitalized identifiers also require special handling when called directly.
> You can wrap in a lowercase combinator or use `apply/3`:
>
>     defparsec :parse, parsec(:Foo)
>     # or
>     apply(MyParser, :Foo, ["foo"])

## Common Patterns

### Whitespace Handling

```peg
ws <- [ \t\n\r]*
token <- ws content ws
```

### Quoted Strings

```peg
string <- '"' (!'"' .)* '"'
```

With escape sequences:

```peg
string <- '"' (escape / !'"' .)* '"'
escape <- '\\' [nrt"\\]
```

### Comments (C-style)

```peg
line_comment <- '//' (!'\n' .)* '\n'
block_comment <- '/*' (!'*/' .)* '*/'
```

### Identifiers

```peg
identifier <- [a-zA-Z_] [a-zA-Z0-9_]*
```

### Numbers

```peg
integer <- '-'? [0-9]+
float <- '-'? [0-9]+ '.' [0-9]+
```

### Separated Lists

```peg
# Comma-separated with optional trailing comma
list <- item (',' item)* ','?

# At least one item
nonempty_list <- item (',' item)*
```

## Debugging Tips

1. **Start simple**: Build your grammar incrementally, testing each rule.

2. **Use `:parser`**: Mark rules you want to test with `parser: true` so you can call them directly.

3. **Check precedence**: When in doubt, add parentheses to make grouping explicit.

4. **Ordered choice matters**: Put more specific alternatives first:
   ```peg
   # Wrong: 'if' matches before 'ifelse'
   keyword <- 'if' / 'ifelse'

   # Right: longer match first
   keyword <- 'ifelse' / 'if'
   ```

5. **Avoid left recursion**: PEG parsers don't support left recursion.

> #### Left Recursion {: .warning}
>
> Left-recursive rules will cause infinite loops:
>
>     # This will infinite loop!
>     expr <- expr '+' term
>
>     # Use iteration instead
>     expr <- term ('+' term)*
