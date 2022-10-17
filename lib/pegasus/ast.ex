defmodule Pegasus.Ast do
  import NimbleParsec

  @enforce_keys [:name]

  defstruct @enforce_keys ++ [:ast, position_traversal?: false, tagged?: false, parsec: empty()]

  def to_nimble_parsec({:ok, list, "", _, _, _}, opts) do
    to_nimble_parsec(list, opts)
  end

  def to_nimble_parsec(ast, opts) when is_list(ast) do
    Enum.map(ast, &to_nimble_parsec(&1, opts))
  end

  def to_nimble_parsec({name, parser_ast}, opts) do
    name_opts = Keyword.get(opts, name, [])

    %__MODULE__{name: name, ast: parser_ast}
    |> from_sequence()

    # |> maybe_add_position(name_opts)
    # |> extract_tag()
    # |> maybe_collect(name_opts)
    # |> maybe_token(name, name_opts)
    # |> maybe_tag(name, name_opts)
    # |> maybe_post_traverse(name_opts)
    # |> maybe_ignore(name_opts)
  end

  # defp maybe_add_position(parsec, name_opts) do
  #  if Keyword.get(name_opts, :start_position) do
  #
  #  end
  # end

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

  defp maybe_ignore(parsec, name_opts) do
    if Keyword.get(name_opts, :ignore) do
      ignore(parsec)
    else
      parsec
    end
  end

  def from_sequence(context) do
    Enum.reduce(context.ast, context, &translate/2)
  end

  defp translate(:dot, context) do
    %{context | parsec: utf8_char(context.parsec, not: 0)}
  end

  defp translate({:char, ranges}, context) do
    %{context | parsec: utf8_char(context.parsec, ranges)}
  end

  defp translate({:literal, literal}, context) do
    %{context | parsec: string(context.parsec, literal)}
  end

  # defp translate({:lookahead, content}, context) do
  #  {parser, new_context} = ungroup(content, context)
  #  %{new_context | parsec: lookahead(context.parsec, parser)}
  # end

  # defp translate({:lookahead_not, content}, context) do
  #  {parser, new_context} = ungroup(content, context)
  #  %{new_context | parsec: lookahead_not(context.parsec, parser)}
  # end

  # defp translate({:optional, content}, context) do
  #  {parser, new_context} = ungroup(content, context)
  #  %{new_context | parsec: optional(context.parsec, parser)}
  # end

  # defp translate({:repeat, content}, context) do
  #  {parser, new_context} = ungroup(content, context)
  #  %{new_context | parsec: repeat(context.parsec, parser)}
  # end

  # defp translate({:times, content}, context) do
  #  {parser, new_context} = ungroup(content, context)
  #  %{new_context | parsec: times(context.parsec, parser, min: 1)}
  # end

  defp translate({:identifier, identifier}, context) do
    %{context | parsec: parsec(context.parsec, identifier)}
  end

  # defp translate({:choice, list_of_choices}, context) do
  #  {choices, new_context} = Enum.reduce(list_of_choices, {[], context}, &reduce_choices/2)
  #  %{new_context | parsec: choice(context.parsec, Enum.reverse(choices))}
  # end

  @group_actions ~w(ungroup extract)a

  # defp translate(grouped = {action, _}, context) when action in @group_actions do
  #  {parser, new_context} = ungroup(context.parsec, grouped, context)
  #  %{new_context | parsec: parser}
  # end

  defp translate(_, context) do
    # TODO: remove this after refactoring
    context
  end

  # defp reduce_choices(choice, {so_far, context}) do
  #  {compiled_choice, new_context} = from_sequence(choice)
  #  {[compiled_choice | so_far], %{context | tagged: context.tagged or new_context.tagged}}
  # end

  # defp ungroup(so_far \\ empty(), grouping, context)
  #
  # defp ungroup(so_far, {:ungroup, grouped}, context) do
  #  operations =
  #    grouped
  #    |> from_sequence
  #    |> extract_tag
  #
  #  {concat(so_far, operations), context}
  # end
  #
  # defp ungroup(so_far, {:extract, grouped}, context) do
  #  operations =
  #    grouped
  #    |> from_sequence
  #    |> extract_tag
  #
  #  tagged =
  #    so_far
  #    |> reduce(operations, {IO, :iodata_to_binary, []})
  #    |> tag(:__tag__)
  #
  #  {tagged, %{context | tagged: true}}
  # end
  #
  # defp ungroup(so_far, ungrouped, context) do
  #  raise "foo"
  # end
end
