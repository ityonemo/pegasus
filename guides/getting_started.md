# Getting Started with Pegasus

This guide walks you through creating your first parser with Pegasus.

## What is Pegasus?

Pegasus is a parser generator that lets you write parsers using PEG (Parsing Expression Grammar) notation. At compile time, Pegasus transforms your grammar into efficient NimbleParsec code.

If you're familiar with tools like YACC, Bison, or ANTLR, Pegasus serves a similar purpose but is designed specifically for Elixir and integrates seamlessly with NimbleParsec.

## Installation

Add Pegasus to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pegasus, "~> 1.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Your First Parser

Let's build a simple parser that parses comma-separated integers.

### Step 1: Define the Grammar

Create a new module and define your grammar:

```elixir
defmodule IntegerListParser do
  require Pegasus

  Pegasus.parser_from_string("""
    list   <- number (',' number)*
    number <- '-'? [0-9]+
  """,
    list: [parser: true],
    number: [collect: true]
  )
end
```

Let's break this down:

- `require Pegasus` - Required to use Pegasus macros
- `parser_from_string/2` - The main macro that generates parsers
- The grammar defines two rules:
  - `list` matches a number followed by zero or more comma-separated numbers
  - `number` matches an optional minus sign followed by one or more digits
- Options configure how rules are compiled:
  - `parser: true` makes `list` a callable entry point
  - `collect: true` combines matched digits into a single string

### Step 2: Use the Parser

```elixir
# Parse a valid list
IntegerListParser.list("1,2,3")
# => {:ok, ["1", "2", "3"], "", %{}, {1, 0}, 5}

# Parse with negative numbers
IntegerListParser.list("-5,10,-3")
# => {:ok, ["-5", "10", "-3"], "", %{}, {1, 0}, 9}

# Parse failure
IntegerListParser.list("not,numbers")
# => {:error, "expected ASCII character in the range \"0\" to \"9\"",
#     "not,numbers", %{}, {1, 0}, 0}
```

### Understanding the Result

A successful parse returns a 6-tuple:

```elixir
{:ok, results, remaining, context, position, byte_offset}
```

- `results` - List of matched values
- `remaining` - Unparsed input (empty string if fully consumed)
- `context` - Parser context (starts as empty map)
- `position` - Current `{line, line_offset}` in the input
- `byte_offset` - Current byte position

A failed parse returns:

```elixir
{:error, message, remaining, context, position, byte_offset}
```

## Converting Results

Raw string results aren't always useful. Use `:post_traverse` to transform them:

```elixir
defmodule IntegerListParser do
  require Pegasus

  Pegasus.parser_from_string("""
    list   <- number (',' number)*
    number <- '-'? [0-9]+
  """,
    list: [parser: true],
    number: [collect: true, post_traverse: {:to_integer, []}]
  )

  defp to_integer(rest, [num_string], context, _position, _offset) do
    {rest, [String.to_integer(num_string)], context}
  end
end

IntegerListParser.list("1,2,3")
# => {:ok, [1, 2, 3], "", %{}, {1, 0}, 5}
```

## Adding Structure with Tags

For more complex parsers, you'll want structured output. Use `:tag` to wrap results:

```elixir
defmodule KeyValueParser do
  require Pegasus

  Pegasus.parser_from_string("""
    pair  <- key '=' value
    key   <- [a-z]+
    value <- [0-9]+
  """,
    pair: [parser: true, tag: :pair],
    key: [collect: true, tag: :key],
    value: [collect: true, tag: :value]
  )
end

KeyValueParser.pair("foo=42")
# => {:ok, [{:pair, [{:key, "foo"}, {:value, "42"}]}], "", %{}, {1, 0}, 6}
```

## Ignoring Content

Use `:ignore` to discard matched content you don't need:

```elixir
defmodule WordParser do
  require Pegasus

  Pegasus.parser_from_string("""
    words <- word (ws word)*
    word  <- [a-zA-Z]+
    ws    <- [ \\t]+
  """,
    words: [parser: true],
    word: [collect: true],
    ws: [ignore: true]
  )
end

WordParser.words("hello world")
# => {:ok, ["hello", "world"], "", %{}, {1, 0}, 11}
```

Without `:ignore`, the whitespace would appear in the results.

## Loading from Files

For larger grammars, store them in separate files:

```
# priv/grammar.peg
expression <- term (('+' / '-') term)*
term       <- number
number     <- [0-9]+
```

```elixir
defmodule ExprParser do
  require Pegasus

  Pegasus.parser_from_file("priv/grammar.peg",
    expression: [parser: true],
    number: [collect: true]
  )
end
```

## Common Patterns

### Optional Whitespace

```
ws     <- [ \t\n\r]*
token  <- ws content ws
```

### Quoted Strings

```
string <- '"' (!'"' .)* '"'
```

### Comments

```
comment <- '#' (![\n\r] .)*
```

### Identifiers

```
ident <- [a-zA-Z_] [a-zA-Z0-9_]*
```

## Next Steps

- Read the [PEG Grammar Reference](peg_grammar.md) for complete syntax documentation
- See [Parser Options](parser_options.md) for all available configuration options
- Check out [Advanced Examples](advanced_examples.md) for real-world parser patterns
