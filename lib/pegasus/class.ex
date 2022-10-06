defmodule Pegasus.Class do
  @moduledoc """
  Produces a "class" parser.

  Note that the output of a "class" parser leaves a NimbleParsec parser in the
  arguments list.

  ```peg
  Class           <- '[' < ( !']' Range )* > ']' Spacing
  ```
  """

  alias Pegasus.Components

  import NimbleParsec

  def parser(previous \\ empty()) do
    previous
    |> tag(
      ignore(string("["))
      |> repeat(
        lookahead_not(string("]"))
        |> optional(string("^"))
        |> Components.range()
      )
      |> ignore(string("]")),
      :class
    )
    |> post_traverse({__MODULE__, :to_parser, []})
    |> Components.spacing()
  end

  def to_parser(rest, [{:class, args} | args_rest], context, _, _) do
    parser = to_ranges(args)

    {rest, [{:char, parser} | args_rest], context}
  end

  defp to_ranges(src_list, so_far \\ [])

  defp to_ranges([], so_far), do: Enum.reverse(so_far)

  defp to_ranges(["^", this | src_rest], so_far) do
    to_ranges(src_rest, [{:not, this} | so_far])
  end

  defp to_ranges([this | src_rest], so_far) do
    to_ranges(src_rest, [this | so_far])
  end
end
