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

  See `NimbleParsec` for the description of the output.  Note that the arguments for the function
  will be tagged with the combinator name.

  ```
  MyModule.foo("foobar") # ==> {:ok, [foo: ["foo", "bar"]]}
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

  ### Post-Traversals

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

  ### Parser

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

  ### Exports

  You may sepecify to export a combinator as a public function by specifying `export: true`.
  By default, the combinators are private functions.

  #### Example

  ```
  Pegasus.parser_from_string(\"""
    foo <- "foo" "bar"
    \""", foo: [export: true]
  )
  ```

  ### Not implemented

  Actions, which imply the use of C code, are not implemented.
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
        exported = !! Keyword.get(name_opts, :export)
        parser = !! Keyword.get(name_opts, :parser)

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
