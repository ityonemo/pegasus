defmodule PegasusTest.LiteralTest do
  use ExUnit.Case, async: true

  alias Pegasus.Literal

  import NimbleParsec
  import PegasusTest.Case

  defparsec(:parser, Literal.parser())

  describe "the literal parser" do
    test "produces a literal string matcher with double quotes" do
      assert_parser(parser(~S("foo")), {:literal, "foo"})
    end

    test "produces a literal string matcher with single quotes" do
      assert_parser(parser(~S('foo')), {:literal, "foo"})
    end

    test "produces a literal string matcher with double quotes and escaped quote" do
      assert_parser(parser(~S("\"foo\"")), {:literal, ~S("foo")})
    end

    test "produces a literal string matcher with single quotes and escaped quote" do
      assert_parser(parser(~S('\'foo\'')), {:literal, ~S('foo')})
    end

    test "produces a literal string matcher with double quotes and escaped return" do
      assert_parser(parser(~S("foo\n")), {:literal, ~s(foo\n)})
    end

    test "produces a literal string matcher with double quotes and escaped number" do
      assert_parser(parser(~S("fo\157")), {:literal, ~s(foo)})
    end
  end
end
