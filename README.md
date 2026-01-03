# Pegasus

[![Hex.pm](https://img.shields.io/hexpm/v/pegasus.svg)](https://hex.pm/packages/pegasus)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/pegasus)
[![License](https://img.shields.io/hexpm/l/pegasus.svg)](https://github.com/ityonemo/pegasus/blob/main/LICENSE)

**Pegasus** is a PEG (Parsing Expression Grammar) parser generator for Elixir. It takes PEG grammar definitions and compiles them into efficient [NimbleParsec](https://github.com/dashbitco/nimble_parsec) parsers at compile time.

## Why Pegasus?

- **Familiar syntax**: Use standard PEG notation instead of learning NimbleParsec's combinator API
- **Compile-time generation**: Parsers are generated at compile time, with zero runtime overhead
- **Full NimbleParsec power**: Access all NimbleParsec features like post-traversal hooks, tagging, and tokenization
- **Battle-tested format**: PEG is a well-documented, widely-used grammar format

## Installation

Add `pegasus` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pegasus, "~> 1.0"}
  ]
end
```

## Quick Start

```elixir
defmodule MyParser do
  require Pegasus

  # Define a simple parser for comma-separated numbers
  Pegasus.parser_from_string("""
    numbers <- number (',' number)*
    number  <- [0-9]+
  """,
    numbers: [parser: true],
    number: [collect: true]
  )
end

# Use the parser
MyParser.numbers("1,2,3")
# => {:ok, ["1", "2", "3"], "", %{}, {1, 0}, 5}
```

## How It Works

Pegasus operates in three stages:

1. **Parse**: Your PEG grammar string is parsed into an AST
2. **Transform**: The AST is converted into NimbleParsec combinators
3. **Compile**: NimbleParsec compiles the combinators into an efficient parser

All of this happens at compile time via Elixir macros, so your final application contains optimized parsing code with no runtime grammar processing.

## PEG Grammar Syntax

Pegasus supports the standard PEG syntax:

| Syntax | Meaning |
|--------|---------|
| `'literal'` or `"literal"` | Match exact string |
| `[a-z]` | Character class (match one character in range) |
| `[^a-z]` | Negated character class |
| `.` | Match any single character |
| `e1 e2` | Sequence (match e1 then e2) |
| `e1 / e2` | Ordered choice (try e1, if it fails try e2) |
| `e*` | Zero or more repetitions |
| `e+` | One or more repetitions |
| `e?` | Optional (zero or one) |
| `&e` | Positive lookahead (match without consuming) |
| `!e` | Negative lookahead (fail if matches) |
| `(e)` | Grouping |
| `<e>` | Extracted group (capture matched text) |
| `# comment` | Line comment |

### Example Grammar

```peg
# A simple arithmetic expression parser
expression <- term (('+' / '-') term)*
term       <- factor (('*' / '/') factor)*
factor     <- number / '(' expression ')'
number     <- [0-9]+
```

## Parser Options

Options are passed as a keyword list to configure how each rule is compiled:

```elixir
Pegasus.parser_from_string(grammar,
  rule_name: [option: value, ...]
)
```

### Common Options

| Option | Description |
|--------|-------------|
| `parser: true` | Export as a parser function (entry point) |
| `export: true` | Make combinator public instead of private |
| `collect: true` | Merge matched content into a single binary |
| `token: :atom` | Replace match with a token value |
| `tag: :atom` | Wrap result in a tagged tuple `{:atom, [...]}` |
| `ignore: true` | Discard the matched content |
| `post_traverse: {fun, args}` | Apply a transformation function |

See the [Parser Options Guide](guides/parser_options.md) for detailed documentation.

## Loading from Files

For larger grammars, load from a `.peg` file:

```elixir
Pegasus.parser_from_file("priv/grammar.peg",
  start: [parser: true]
)
```

## Documentation

- [Getting Started Guide](guides/getting_started.md) - Tutorial introduction
- [PEG Grammar Reference](guides/peg_grammar.md) - Complete syntax reference
- [Parser Options Guide](guides/parser_options.md) - All configuration options
- [Advanced Examples](guides/advanced_examples.md) - Real-world patterns

## PEG Reference

For the original PEG specification, see:
https://www.piumarta.com/software/peg/peg.1.html

## License

MIT License - see [LICENSE](LICENSE) for details.
