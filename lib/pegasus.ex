defmodule Pegasus do
  @moduledoc """
  converts `.peg` files into NimbleParsec parsers
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
