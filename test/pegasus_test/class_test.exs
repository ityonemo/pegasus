defmodule PegasusTest.ClassTest do
  use ExUnit.Case, async: true

  alias Pegasus.Class

  import NimbleParsec
  import PegasusTest.Case

  defparsec(:parser, Class.parser())

  describe "the class parser" do
    test "produces a single char class" do
      assert_parser(parser("[a]"), {:char, ~C(a)})
    end

    test "produces a char range class" do
      assert_parser(parser("[a-z]"), {:char, [?a..?z]})
    end

    test "can match multiple chars" do
      assert_parser(parser("[ac]"), {:char, ~C(ac)})
    end

    test "can match a char and a range" do
      assert_parser(parser("[ad-z]"), {:char, [?a, ?d..?z]})
    end

    test "can negate a char" do
      assert_parser(parser("[^a]"), {:char, not: ?a})
    end

    test "can negate a range" do
      assert_parser(parser("[^a-z]"), {:char, not: ?a..?z})
    end
  end
end
