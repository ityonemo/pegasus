defmodule PegasusTest.SequenceTest do
  use ExUnit.Case, async: true

  alias Pegasus.Sequence

  import NimbleParsec
  import PegasusTest.Case

  defparsec(:parser, Sequence.parser())

  describe "the sequence parser" do
    test "produces a single normal sequence" do
      assert_parser(parser(~S("foo")), literal: "foo")
    end

    test "produces a sequnential normal sequences" do
      assert_parser(parser(~S("foo" 'bar')), literal: "foo", literal: "bar")
    end

    test "identifies lookahead" do
      assert_parser(parser(~S(&"foo")), lookahead: {:literal, "foo"})
    end

    test "identifies lookahead_not" do
      assert_parser(parser(~S(!"foo")), lookahead_not: {:literal, "foo"})
    end

    test "identifies optional" do
      assert_parser(parser(~S("foo"?)), optional: {:literal, "foo"})
    end

    test "identifies repeat" do
      assert_parser(parser(~S("foo"*)), repeat: {:literal, "foo"})
    end

    test "identifies times" do
      assert_parser(parser(~S("foo"+)), times: {:literal, "foo"})
    end

    test "identifies lookahead_not, times" do
      assert_parser(parser(~S(!"foo"+)), lookahead_not: {:times, {:literal, "foo"}})
    end
  end
end
