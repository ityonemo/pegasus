# Parser Options Reference

This guide documents all options available when configuring Pegasus parsers.

## Overview

Options are passed as a keyword list to `parser_from_string/2` or `parser_from_file/2`. Each key is a rule name, and each value is a list of options for that rule:

```elixir
Pegasus.parser_from_string("""
  start <- number (',' number)*
  number <- [0-9]+
""",
  start: [parser: true],
  number: [collect: true, tag: :num]
)
```

## Option Application Order

Options are applied in this order:

1. `:start_position` - Inject position information
2. `:collect` - Merge content into binary
3. `:token` - Replace with token value
4. `:tag` - Wrap in tagged tuple
5. `:post_traverse` - Custom transformation
6. `:ignore` - Discard content
7. `:alias` - Substitute combinator

This order matters! For example, `:collect` happens before `:tag`, so you can collect characters into a string and then tag the result.

## Options Reference

### `:parser`

Marks a rule as an entry point that can be called directly.

**Values:**
- `true` - Create a parser with the rule name
- `:custom_name` - Create a parser with a custom name

**Without `:parser`:** Rules become private combinators only usable by other rules.

**With `:parser`:** The rule becomes a callable function returning `{:ok, result, rest, ...}` or `{:error, ...}`.

```elixir
Pegasus.parser_from_string("""
  start <- greeting name
  greeting <- 'Hello, '
  name <- [a-zA-Z]+
""", start: [parser: true])

# Now you can call:
MyModule.start("Hello, World")
```

**Renaming:**

```elixir
Pegasus.parser_from_string("""
  internal_name <- [a-z]+
""", internal_name: [parser: :parse])

# Creates `parse/1` instead of `internal_name/1`
MyModule.parse("hello")
```

### `:export`

Makes a combinator public instead of private.

**Values:**
- `true` - Export the combinator

**Default:** Combinators are private (`defcombinatorp`).

Use this when you need to reference a combinator from outside the module or compose it with other NimbleParsec combinators.

```elixir
Pegasus.parser_from_string("""
  number <- [0-9]+
""", number: [export: true, collect: true])

# In another module:
import NimbleParsec
defparsec :my_parser, parsec({OtherModule, :number})
```

### `:collect`

Merges all matched content into a single binary string.

**Values:**
- `true` - Collect into binary

Without `:collect`, character matches remain as separate elements:

```elixir
# Without collect
# [0-9]+ matching "123" produces: [49, 50, 51] (character codes)

# With collect
# [0-9]+ matching "123" produces: "123"
```

> #### Collect Requirements {: .warning}
>
> When using `:collect`, all content must be iodata (binaries or character codes).
> Tags and tokens will cause errors.

```elixir
Pegasus.parser_from_string("""
  number <- sign? digits
  sign <- '-' / '+'
  digits <- [0-9]+
""",
  number: [parser: true, collect: true]
)

MyModule.number("-42")
# => {:ok, ["-42"], "", ...}
```

### `:token`

Replaces matched content with a token value.

**Values:**
- `true` - Use the rule name as the token
- `:custom` - Use a custom atom as the token
- Any term - Use that value as the token

Tokens are useful for lexer-style parsing where you want to classify matches:

```elixir
Pegasus.parser_from_string("""
  keyword <- 'if' / 'else' / 'while' / 'for'
""", keyword: [parser: true, collect: true, token: :keyword])

MyModule.keyword("while")
# => {:ok, [:keyword], "", ...}
```

**With `token: true`:**

```elixir
Pegasus.parser_from_string("""
  if_keyword <- 'if'
  else_keyword <- 'else'
""",
  if_keyword: [token: true],
  else_keyword: [token: true]
)

# 'if' becomes :if_keyword
# 'else' becomes :else_keyword
```

### `:tag`

Wraps the result in a tagged tuple `{tag, content}`.

**Values:**
- `true` - Use the rule name as the tag
- `:custom` - Use a custom atom as the tag
- Any term - Use that value as the tag

```elixir
Pegasus.parser_from_string("""
  pair <- key '=' value
  key <- [a-z]+
  value <- [0-9]+
""",
  pair: [parser: true],
  key: [collect: true, tag: :key],
  value: [collect: true, tag: :value]
)

MyModule.pair("foo=42")
# => {:ok, [{:key, "foo"}, {:value, "42"}], "", ...}
```

**Nested tags:**

```elixir
Pegasus.parser_from_string("""
  pair <- key '=' value
  key <- [a-z]+
  value <- [0-9]+
""",
  pair: [parser: true, tag: :pair],
  key: [collect: true, tag: :key],
  value: [collect: true, tag: :value]
)

MyModule.pair("foo=42")
# => {:ok, [{:pair, [{:key, "foo"}, {:value, "42"}]}], "", ...}
```

### `:ignore`

Discards matched content from the result.

**Values:**
- `true` - Ignore the matched content

Use this for whitespace, delimiters, and other syntax that shouldn't appear in the result:

```elixir
Pegasus.parser_from_string("""
  list <- item (sep item)*
  item <- [a-z]+
  sep <- [ ,]+
""",
  list: [parser: true],
  item: [collect: true],
  sep: [ignore: true]
)

MyModule.list("foo, bar, baz")
# => {:ok, ["foo", "bar", "baz"], "", ...}
# Without ignore: ["foo", ", ", "bar", ", ", "baz"]
```

### `:start_position`

Injects position information at the start of the match.

**Values:**
- `true` - Add position map

The position map contains:
- `:line` - Line number (1-based)
- `:column` - Column number (1-based)
- `:offset` - Byte offset from start

```elixir
Pegasus.parser_from_string("""
  token <- [a-z]+
""", token: [parser: true, start_position: true, collect: true])

MyModule.token("hello")
# => {:ok, [%{line: 1, column: 1, offset: 0}, "hello"], "", ...}
```

This is useful for error reporting and source mapping.

### `:post_traverse`

Applies a custom transformation function after parsing.

**Values:**
- `{:function_name, args}` - Call function with additional args
- `:function_name` - Shorthand for `{:function_name, []}`

The function receives:
1. `rest` - Remaining unparsed input
2. `args` - Matched content (**in reversed order!**)
3. `context` - Parser context
4. `position` - `{line, line_offset}` tuple
5. `byte_offset` - Current byte position

It must return `{rest, new_args, context}`.

```elixir
defmodule MyParser do
  require Pegasus

  Pegasus.parser_from_string("""
    number <- '-'? [0-9]+
  """, number: [parser: true, collect: true, post_traverse: {:to_integer, []}])

  defp to_integer(rest, [num_string], context, _position, _offset) do
    {rest, [String.to_integer(num_string)], context}
  end
end

MyParser.number("-42")
# => {:ok, [-42], "", ...}
```

> #### Arguments Are Reversed {: .warning}
>
> The `args` parameter is in **reversed** order from how content was matched.

```elixir
Pegasus.parser_from_string("""
  pair <- first ',' second
  first <- [a-z]+
  second <- [0-9]+
""", pair: [parser: true, post_traverse: {:handle_pair, []}])

# When parsing "abc,123":
defp handle_pair(rest, [second, ",", first], context, _, _) do
  # second = "123", first = "abc" (reversed!)
  {rest, [{first, second}], context}
end
```

**With extra arguments:**

```elixir
Pegasus.parser_from_string("""
  number <- [0-9]+
""", number: [collect: true, post_traverse: {:parse_base, [16]}])

defp parse_base(rest, [digits], context, _, _, base) do
  {rest, [String.to_integer(digits, base)], context}
end
```

### `:alias`

Substitutes a custom combinator in place of the grammar rule.

**Values:**
- `:combinator_name` - Use this combinator instead

The grammar rule is ignored; only the referenced combinator is used.

```elixir
defmodule MyParser do
  require Pegasus
  import NimbleParsec

  # Define a custom combinator
  defcombinatorp :my_special_parser,
    ascii_string([?a..?z], min: 1)
    |> map({String, :upcase, []})

  Pegasus.parser_from_string("""
    word <- [a-z]+
  """, word: [parser: true, alias: :my_special_parser])
end

MyParser.word("hello")
# => {:ok, ["HELLO"], "", ...}
```

Use `:alias` when:
- The PEG syntax can't express what you need
- You need NimbleParsec-specific features
- You're gradually migrating from NimbleParsec to Pegasus

## Combining Options

Options compose naturally:

```elixir
Pegasus.parser_from_string("""
  token <- [a-zA-Z]+
""",
  token: [
    parser: true,
    start_position: true,  # 1. Add position
    collect: true,         # 2. Merge to string
    tag: :identifier       # 3. Wrap in tuple
  ]
)

MyModule.token("hello")
# => {:ok, [{:identifier, [%{line: 1, column: 1, offset: 0}, "hello"]}], "", ...}
```

## Common Patterns

### Lexer Tokens

```elixir
Pegasus.parser_from_string("""
  tokens <- (keyword / identifier / number / ws)*
  keyword <- 'if' / 'else' / 'while'
  identifier <- [a-zA-Z_] [a-zA-Z0-9_]*
  number <- [0-9]+
  ws <- [ \\t\\n]+
""",
  tokens: [parser: true],
  keyword: [collect: true, token: :keyword],
  identifier: [collect: true, token: :ident],
  number: [collect: true, token: :number],
  ws: [ignore: true]
)
```

### AST Building

```elixir
Pegasus.parser_from_string("""
  expr <- term (('+' / '-') term)*
  term <- number
  number <- [0-9]+
""",
  expr: [parser: true, tag: :expr],
  term: [tag: :term],
  number: [collect: true, post_traverse: {:to_int, []}]
)
```

### Error Positions

```elixir
Pegasus.parser_from_string("""
  statement <- keyword ws expr
  keyword <- 'let' / 'var'
  expr <- [a-z]+
  ws <- [ ]+
""",
  statement: [parser: true],
  keyword: [start_position: true, collect: true, tag: :keyword],
  expr: [start_position: true, collect: true, tag: :expr],
  ws: [ignore: true]
)
```
