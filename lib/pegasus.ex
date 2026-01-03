defmodule Pegasus do
  @moduledoc """
  A PEG (Parsing Expression Grammar) parser generator for Elixir.

  Pegasus compiles PEG grammar definitions into efficient `NimbleParsec` parsers
  at compile time. This gives you the familiar, readable PEG syntax while leveraging
  NimbleParsec's optimized parsing engine.

  ## Quick Start

      defmodule MyParser do
        require Pegasus

        Pegasus.parser_from_string(\"""
          numbers <- number (',' number)*
          number  <- [0-9]+
        \""",
          numbers: [parser: true],
          number: [collect: true]
        )
      end

      MyParser.numbers("1,2,3")
      # => {:ok, ["1", "2", "3"], "", %{}, {1, 0}, 5}

  ## Main API

  - `parser_from_string/2` - Define parsers from a PEG grammar string
  - `parser_from_file/2` - Load and compile a PEG grammar from a file
  - `parser_from_ast/2` - Advanced: compile a pre-parsed AST

  ## PEG Grammar Syntax

  Pegasus supports the standard PEG syntax. For the full specification, see the
  [PEG reference](https://www.piumarta.com/software/peg/peg.1.html).

  ### Rules

  Rules are defined with the `<-` operator:

      identifier <- expression

  ### Expressions

  | Syntax | Description | Example |
  |--------|-------------|---------|
  | `'...'` or `"..."` | Literal string | `'hello'` |
  | `[...]` | Character class | `[a-zA-Z]` |
  | `[^...]` | Negated character class | `[^0-9]` |
  | `.` | Any character | `.` |
  | `e1 e2` | Sequence | `'a' 'b'` |
  | `e1 / e2` | Ordered choice | `'a' / 'b'` |
  | `e*` | Zero or more | `[0-9]*` |
  | `e+` | One or more | `[0-9]+` |
  | `e?` | Optional | `'-'?` |
  | `&e` | Positive lookahead | `&'x'` |
  | `!e` | Negative lookahead | `!'x'` |
  | `(e)` | Grouping | `('a' 'b')*` |
  | `<e>` | Extracted group | `<[a-z]+>` |
  | `# ...` | Comment | `# this is ignored` |

  ### Escape Sequences

  Pegasus supports ANSI C escape sequences in literals and character classes:

  - `\\a` - bell
  - `\\b` - backspace
  - `\\e` - escape
  - `\\f` - form feed
  - `\\n` - newline
  - `\\r` - carriage return
  - `\\t` - tab
  - `\\v` - vertical tab
  - `\\'` - single quote
  - `\\"` - double quote
  - `\\\\` - backslash
  - `\\[` and `\\]` - brackets (useful in character classes)
  - `\\-` - literal hyphen (in character classes)
  - `\\377` - octal escape (1-3 octal digits)

  ## Parser Options

  Options control how each grammar rule is compiled. Pass them as a keyword list
  where keys are rule names:

      Pegasus.parser_from_string(grammar,
        rule_name: [option: value, ...]
      )

  Options are applied in the order specified.

  ### `:parser`

  Export the rule as a parser function (an entry point that can be called directly).
  Without this option, rules become private combinators.

      Pegasus.parser_from_string(\"""
        start <- greeting name
        greeting <- 'Hello, '
        name <- [a-zA-Z]+
      \""", start: [parser: true])

  The `:parser` option also accepts an atom to rename the parser:

      Pegasus.parser_from_string("foo <- 'foo'", foo: [parser: :parse])
      # Creates `parse/1` instead of `foo/1`

  ### `:export`

  Make a combinator public instead of private. Use this when you need to reference
  the combinator from other modules or compose it with other NimbleParsec combinators.

      Pegasus.parser_from_string(\"""
        foo <- 'foo'
      \""", foo: [export: true])

  ### `:collect`

  Merge all matched content into a single binary string. Useful for rules that match
  multiple characters you want combined.

      Pegasus.parser_from_string(\"""
        number <- [0-9]+
      \""", number: [collect: true])

      # Without collect: ["1", "2", "3"]
      # With collect: "123"

  > #### Collect requirements {: .warning}
  > When using `:collect`, all nested combinators must leave only iodata
  > (binaries/charlists) in the result. Tags and tokens will cause errors.

  ### `:token`

  Replace the matched content with a token value.

  - `token: true` - Use the rule name as the token
  - `token: :custom` - Use a custom atom as the token

      Pegasus.parser_from_string(\"""
        operator <- '+' / '-' / '*' / '/'
      \""", operator: [collect: true, token: :op])

      # Matched "+" becomes :op

  ### `:tag`

  Wrap the result in a tagged tuple `{tag, content}`.

  - `tag: true` - Use the rule name as the tag
  - `tag: :custom` - Use a custom atom as the tag

      Pegasus.parser_from_string(\"""
        number <- [0-9]+
      \""", number: [collect: true, tag: :num])

      # Result: {:num, "123"}

  ### `:ignore`

  Discard the matched content. Useful for whitespace and delimiters.

      Pegasus.parser_from_string(\"""
        list <- item (',' item)*
        item <- [a-z]+
      \""",
        list: [parser: true],
        item: [collect: true]
      )

  ### `:start_position`

  Inject position information at the start of the match. Adds a map with
  `:line`, `:column`, and `:offset` keys.

      Pegasus.parser_from_string(\"""
        token <- [a-z]+
      \""", token: [start_position: true, collect: true])

      # Result: [%{line: 1, column: 0, offset: 0}, "hello"]

  ### `:post_traverse`

  Apply a custom transformation function after the rule matches. The function
  receives the parsing state and can transform the results.

      Pegasus.parser_from_string(\"""
        number <- [0-9]+
      \""", number: [collect: true, post_traverse: {:to_integer, []}])

      defp to_integer(rest, [num_string], context, _position, _offset) do
        {rest, [String.to_integer(num_string)], context}
      end

  > #### Arguments are reversed {: .info}
  > The second argument (matched content) is in **reversed** order from how
  > it was matched. Plan accordingly when pattern matching.

  ### `:alias`

  Substitute a custom combinator in place of the grammar rule. Useful when
  you need special handling that PEG syntax can't express.

      Pegasus.parser_from_string(\"""
        special <- 'x'
      \""", special: [alias: :my_custom_combinator])

  You must define `my_custom_combinator` as a NimbleParsec combinator in
  your module.

  ## Capitalized Identifiers

  Due to Elixir's naming conventions, capitalized rule names require special
  handling when called directly:

      defmodule MyParser do
        require Pegasus
        import NimbleParsec

        Pegasus.parser_from_string("Foo <- 'foo'")

        # Wrap in a lowercase parser to call it
        defparsec :parse, parsec(:Foo)
      end

  Alternatively, use `apply/3`:

      apply(MyParser, :Foo, ["foo"])

  ## Loading from Files

  For larger grammars, store them in `.peg` files:

      # In lib/my_parser.ex
      Pegasus.parser_from_file("priv/grammar.peg",
        start: [parser: true]
      )

  ## Output Format

  Parsers return the standard `NimbleParsec` result tuple:

      {:ok, results, remaining, context, position, byte_offset}

  Or on failure:

      {:error, message, remaining, context, position, byte_offset}

  See `NimbleParsec` documentation for details.

  ## Not Implemented

  PEG actions (C code blocks like `{ code }`) are not supported, as they are
  specific to the C implementation. Use `:post_traverse` for custom transformations.
  """

  import NimbleParsec

  defparsec(:parse, Pegasus.Grammar.parser())

  defmacro parser_from_string(string, opts \\ []) do
    quote bind_quoted: [string: string, opts: opts] do
      string
      |> Pegasus.parse()
      |> Pegasus.parser_from_ast(opts)
    end
  end

  defmacro parser_from_file(file, opts \\ []) do
    quote bind_quoted: [file: file, opts: opts] do
      file
      |> File.read!()
      |> Pegasus.parse()
      |> Pegasus.parser_from_ast(opts)
    end
  end

  defmacro parser_from_ast(ast, opts) do
    quote bind_quoted: [ast: ast, opts: opts] do
      require NimbleParsec
      require Pegasus.Ast

      for ast = %{name: name, parsec: parsec} <- Pegasus.Ast.to_nimble_parsec(ast, opts) do
        name_opts = Keyword.get(opts, name, [])
        exported = !!Keyword.get(name_opts, :export)
        parser = Keyword.get(name_opts, :parser, false)

        Pegasus.Ast.traversals(ast)

        case {exported, parser} do
          {false, false} ->
            NimbleParsec.defcombinatorp(name, parsec)

          {false, true} ->
            NimbleParsec.defparsecp(name, parsec)

          {false, parser_name} ->
            NimbleParsec.defparsecp(parser_name, parsec)

          {true, false} ->
            NimbleParsec.defcombinator(name, parsec)

          {true, true} ->
            NimbleParsec.defparsec(name, parsec, export_combinator: true)

          {true, parser_name} ->
            NimbleParsec.defparsec(parser_name, parsec, export_combinator: true)
        end
      end
    end
  end
end
