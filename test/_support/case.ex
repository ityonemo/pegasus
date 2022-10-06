defmodule PegasusTest.Case do
  defmacro assert_parsed(
             value,
             args \\ quote do
               _
             end
           ) do
    quote do
      assert {:ok, unquote(args), "", %{}, _, _} = unquote(value)
    end
  end

  defmacro assert_parser(value, parser) do
    quote bind_quoted: [value: value, parser: parser] do
      assert {:ok, [^parser], "", %{}, _, _} = value
    end
  end

  defmacro refute_parsed(value = {_, _, [source]}) do
    quote bind_quoted: [value: value, source: source] do
      case value do
        error when elem(error, 0) == :error ->
          assert {:error, _msg, _rest, _context, _, _} = value

        _ ->
          assert {:ok, [], ^source, %{}, _, _} = value
      end
    end
  end
end
