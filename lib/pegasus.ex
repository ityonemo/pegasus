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

  Now each included parser identifier is turned into a public function.

  See `NimbleParsec` for the definition

  ```
  MyModule.foo("foobar")
  ```

  Note: for capitalized identifiers, you will have to use Kernel.apply/2 to call
  the function.

  You may also load a parser from a file using `parser_from_file/2`.

  ### Post-Traversals

  You may supply a post_traversal for any parser.  See `NimbleParsec` for how to
  implement post-traversal functions.  These are defined by passing a keyword list
  to the `parser_from_file/2` or `parser_from_string/2` function.

  #### Example

  ```
  Pegasus.parser_from_string(\"""
  foo <- "foo" "bar"
  \""", foo: {:some_function, []})

  defp foo(rest, ["bar", "foo"], context, {_line, _col}, _bytes) do
    {rest, [:parsed], context}
  end
  ```

  ### Not implemented

  Actions, which imply the use of C code, are not implemented.
  """

  import NimbleParsec

  defparsec(:parse, Pegasus.Grammar.parser())

  defmacro parser_from_string(string, post_traversals \\ []) do
    quote bind_quoted: [string: string, post_traversals: post_traversals] do
      string
      |> Pegasus.parse()
      |> Pegasus.parser_from_ast(post_traversals)
    end
  end

  defmacro parser_from_file(file, post_traversals \\ []) do
    quote bind_quoted: [file: file, post_traversals: post_traversals] do
      file
      |> File.read!()
      |> Pegasus.parse()
      |> Pegasus.parser_from_ast(post_traversals)
    end
  end

  defmacro parser_from_ast(ast, post_traversals) do
    quote bind_quoted: [ast: ast, post_traversals: post_traversals] do
      require NimbleParsec

      for {name, defn} <- Pegasus.Ast.to_nimble_parsec(ast, post_traversals) do
        NimbleParsec.defparsec(name, defn)
      end
    end
  end
end
