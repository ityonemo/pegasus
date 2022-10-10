defmodule Pegasus.Ast do
  import NimbleParsec

  defstruct tagged: false

  def to_nimble_parsec({:ok, list, "", _, _, _}, opts) do
    to_nimble_parsec(list, opts)
  end

  def to_nimble_parsec(ast, opts) when is_list(ast) do
    Enum.map(ast, &to_nimble_parsec(&1, opts))
  end

  def to_nimble_parsec({name, parser_ast}, opts) do
    name_opts = Keyword.get(opts, name, [])

    parser =
      parser_ast
      |> from_sequence()
      |> extract_tag()
      |> maybe_collect(name_opts)
      |> maybe_token(name, name_opts)
      |> maybe_tag(name, name_opts)
      |> maybe_post_traverse(name_opts)

    {name, parser}
  end

  defp extract_tag({parsec, context}) do
    if Map.get(context, :tagged) do
      parsec
      |> reduce({Enum, :find, [&is_tuple/1]})
      |> map({Kernel, :elem, [1]})
      |> map({IO, :iodata_to_binary, []})
    else
      parsec
    end
  end

  defp maybe_collect(parsec, name_opts) do
    if Keyword.get(name_opts, :collect) do
      reduce(parsec, {IO, :iodata_to_binary, []})
    else
      parsec
    end
  end

  defp maybe_token(parsec, name, name_opts) do
    case Keyword.get(name_opts, :token, false) do
      false -> parsec
      true -> parsec |> tag(name) |> map({Kernel, :elem, [0]})
      token -> parsec |> tag(token) |> map({Kernel, :elem, [0]})
    end
  end

  defp maybe_tag(parsec, name, name_opts) do
    case Keyword.get(name_opts, :tag, false) do
      false -> parsec
      true -> tag(parsec, name)
      tag -> tag(parsec, tag)
    end
  end

  defp maybe_post_traverse(parsec, name_opts) do
    if post_traverse = Keyword.get(name_opts, :post_traverse) do
      post_traverse(parsec, post_traverse)
    else
      parsec
    end
  end

  def from_sequence(parser_ast) do
    Enum.reduce(parser_ast, {empty(), %__MODULE__{}}, &translate/2)
  end

  defp translate(:dot, {so_far, context}) do
    {utf8_char(so_far, not: 0), context}
  end

  defp translate({:char, ranges}, {so_far, context}) do
    {utf8_char(so_far, ranges), context}
  end

  defp translate({:literal, literal}, {so_far, context}) do
    {string(so_far, literal), context}
  end

  defp translate({:lookahead, content}, {so_far, context}) do
    {parser, new_context} = ungroup(content, context)
    {lookahead(so_far, parser), new_context}
  end

  defp translate({:lookahead_not, content}, {so_far, context}) do
    {parser, new_context} = ungroup(content, context)
    {lookahead_not(so_far, parser), new_context}
  end

  defp translate({:optional, content}, {so_far, context}) do
    {parser, new_context} = ungroup(content, context)
    {optional(so_far, parser), new_context}
  end

  defp translate({:repeat, content}, {so_far, context}) do
    {parser, new_context} = ungroup(content, context)
    {repeat(so_far, parser), new_context}
  end

  defp translate({:times, content}, {so_far, context}) do
    {parser, new_context} = ungroup(content, context)
    {times(so_far, parser, min: 1), new_context}
  end

  defp translate({:identifier, identifier}, {so_far, context}) do
    {parsec(so_far, identifier), context}
  end

  defp translate({:choice, list_of_choices}, {so_far, context}) do
    {choices, new_context} = Enum.reduce(list_of_choices, {[], context}, &reduce_choices/2)
    {choice(so_far, Enum.reverse(choices)), new_context}
  end

  @group_actions ~w(ungroup extract)a

  defp translate(grouped = {action, _}, {so_far, context}) when action in @group_actions do
    ungroup(so_far, grouped, context)
  end

  defp reduce_choices(choice, {so_far, context}) do
    {compiled_choice, new_context} = from_sequence(choice)
    {[compiled_choice | so_far], %{context | tagged: context.tagged or new_context.tagged}}
  end

  defp ungroup(so_far \\ empty(), grouping, context)

  defp ungroup(so_far, {:ungroup, grouped}, context) do
    operations =
      grouped
      |> from_sequence
      |> extract_tag

    {concat(so_far, operations), context}
  end

  defp ungroup(so_far, {:extract, grouped}, context) do
    operations =
      grouped
      |> from_sequence
      |> extract_tag

    tagged =
      so_far
      |> reduce(operations, {IO, :iodata_to_binary, []})
      |> tag(:__tag__)

    {tagged, %{context | tagged: true}}
  end

  defp ungroup(so_far, ungrouped, context) do
    {parser, new_context} = translate(ungrouped, {empty(), context})
    {concat(so_far, parser), new_context}
  end
end
