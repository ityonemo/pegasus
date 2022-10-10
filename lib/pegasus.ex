defmodule Pegasus do
  @moduledoc """
  converts `peg` files into `NimbleParsec` parsers.

  For documentation on this peg format:  https://www.piumarta.com/software/peg/peg.1.html

  To use, drop this in your model:

  ```
  defmodule MyModule
    require Pegasus

    Pegasus.parser_from_string(\"""
    foo <- "foo" "bar"
    \""")
  end
  ```

  See `NimbleParsec` for the description of the output.

  ```
  MyModule.foo("foobar") # ==> {:ok, ["foo", "bar"], ...}
  ```

  > #### Capitalized Identifiers {: .warning}
  >
  > for capitalized identifiers, you will have to use `apply/3` to call the
  > function, or you may wrap it in another combinator like so:
  >
  > ```elixir
  > defmodule Capitalized do
  >   require Pegasus
  >   import NimbleParsec
  >
  >   Pegasus.parser_from_string("Foo <- 'foo'")
  >
  >   defparsec :parse, parsec(:Foo)
  > end
  > ```

  You may also load a parser from a file using `parser_from_file/2`.

  ## Parser Options

  Parser options are passed as a keyword list after the parser defintion
  string (or file).  The keys for the options are the names of the combinators,
  followed by a keyword list of supplied options, which are applied in the
  specified order:

  ### `:collect`

  You may collect the contents of a combinator using the `collect: true` option.
  If this combinator calls other combinators, they must leave only iodata (no
  tags, no tokens) in the arguments list.

  ### `:token`

  You may substitute the contents of any combinator with a token (usually an atom).
  The following conditions apply:

  - `token: false` - no token (default)
  - `token: true` - token is set to the atom name of the combinator
  - `token: <value>` - token is set to the value of setting

  ### `:tag`

  You may tag the contents of your combinator using the `:tag` option.  The
  following conditions apply:

  - `tag: false` - No tag (default)
  - `tag: true` - Use the combinator name as the tag.
  - `tag: <atom>` - Use the supplied atom as the tag.

  ### `:post_traverse`

  You may supply a post_traversal for any parser.  See `NimbleParsec` for how to
  implement post-traversal functions.  These are defined by passing a keyword list
  to the `parser_from_file/2` or `parser_from_string/2` function.

  #### Example

  ```
  Pegasus.parser_from_string(\"""
    foo <- "foo" "bar"
    \""",
    foo: [post_traverse: {:some_function, []}]
  )

  defp foo(rest, ["bar", "foo"], context, {_line, _col}, _bytes) do
    {rest, [:parsed], context}
  end
  ```

  ### `:parser`

  You may sepecify to export a combinator as a parser by specifying `parser: true`.
  By default, only a combinator will be generated.  See `NimbleParsec.defparsec/3`
  to understand the difference.

  #### Example

  ```
  Pegasus.parser_from_string(\"""
    foo <- "foo" "bar"
    \""", foo: [parser: true]
  )
  ```

  ### `:export`

  You may sepecify to export a combinator as a public function by specifying `export: true`.
  By default, the combinators are private functions.

  #### Example

  ```
  Pegasus.parser_from_string(\"""
    foo <- "foo" "bar"
    \""", foo: [export: true]
  )
  ```

  ## Not implemented features

  Actions, which imply the use of C code, are not implemented.  These currently fail to parse
  but in the future they may silently do nothing.
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

      for {name, defn} <- Pegasus.Ast.to_nimble_parsec(ast, opts) do
        name_opts = Keyword.get(opts, name, [])
        exported = !!Keyword.get(name_opts, :export)
        parser = !!Keyword.get(name_opts, :parser)

        case {exported, parser} do
          {false, false} ->
            NimbleParsec.defcombinatorp(name, defn)

          {false, true} ->
            NimbleParsec.defparsecp(name, defn)

          {true, false} ->
            NimbleParsec.defcombinator(name, defn)

          {true, true} ->
            NimbleParsec.defparsec(name, defn)
        end
      end
    end
  end
end
