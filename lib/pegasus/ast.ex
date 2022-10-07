defmodule Pegasus.Ast do
  import NimbleParsec

  def to_nimble_parsec({:ok, list, "", _, _, _}, opts) do
    to_nimble_parsec(list, opts)
  end

  def to_nimble_parsec(ast, opts) when is_list(ast) do
    Enum.map(ast, &to_nimble_parsec(&1, opts))
  end

  def to_nimble_parsec({name, parser_ast}, opts) do
    name_opts = Keyword.get(opts, name, [])

    parser = parser_ast
    |> from_sequence()
    |> maybe_tag(name, name_opts)
    |> maybe_post_traverse(name_opts)

    {name, parser}
  end

  defp maybe_tag(parsec, name, name_opts) do
    case Keyword.get(name_opts, :tag, name) do
      false -> parsec
      tag -> tag(parsec, tag)
    end
  end

  defp maybe_post_traverse(parsec, name_opts) do
    if post_traverse = Keyword.get(name_opts, :post_tarverse) do
      post_traverse(parsec, post_traverse)
    else
      parsec
    end
  end

  def from_sequence(parser_ast) do
    Enum.reduce(parser_ast, empty(), &translate/2)
  end

  defp translate(:dot, so_far) do
    utf8_char(so_far, not: 0)
  end

  defp translate({:char, ranges}, so_far) do
    utf8_char(so_far, ranges)
  end

  defp translate({:literal, literal}, so_far) do
    string(so_far, literal)
  end

  defp translate({:lookahead, content}, so_far) do
    lookahead(so_far, ungroup(content))
  end

  defp translate({:lookahead_not, content}, so_far) do
    lookahead_not(so_far, ungroup(content))
  end

  defp translate({:optional, content}, so_far) do
    optional(so_far, ungroup(content))
  end

  defp translate({:repeat, content}, so_far) do
    repeat(so_far, ungroup(content))
  end

  defp translate({:times, content}, so_far) do
    times(so_far, ungroup(content), min: 1)
  end

  defp translate({:identifier, identifier}, so_far) do
    parsec(so_far, identifier)
  end

  defp translate({:choice, list_of_choices}, so_far) do
    choice(so_far, Enum.map(list_of_choices, &from_sequence/1))
  end

  defp translate({:grouped, grouped}, so_far) do
    reduce(so_far, from_sequence(grouped), {IO, :iodata_to_binary, []})
  end

  defp translate({:tagged, grouped}, so_far) do
    reduce(so_far, from_sequence(grouped), {IO, :iodata_to_binary, []})
  end

  defp ungroup({:grouped, grouped}) do
    grouped
    |> from_sequence
    |> reduce({IO, :iodata_to_binary, []})
  end

  defp ungroup({:tagged, grouped}) do
    grouped
    |> from_sequence
    |> reduce({IO, :iodata_to_binary, []})
  end

  defp ungroup(ungrouped), do: translate(ungrouped, [])
end
