defmodule PegasusTest.IdentifierTest do
  use ExUnit.Case, async: true

  alias Pegasus.Identifier

  import NimbleParsec
  import PegasusTest.Case

  defparsec(:parser, Identifier.parser(empty(), true))
  defparsec(:definer, Identifier.parser(empty()))

  describe "the identifier parser" do
    test "produces a tagged identifier parser" do
      assert_parser(parser("foo"), {:parser, :foo})
    end

    test "fails on a non-identifer" do
      refute_parsed(parser("5oo"))
    end
  end

  describe "the indentifier definer" do
    test "produces a tagged identifier identifier" do
      assert_parser(definer("foo"), {:identifier, :foo})
    end

    test "fails on a non-identifer" do
      refute_parsed(parser("5oo"))
    end
  end
end
