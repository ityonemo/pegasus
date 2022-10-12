defmodule PegasusTest.RegressionTest do
  use ExUnit.Case, async: true

  require Pegasus
  import PegasusTest.Case

  Pegasus.parser_from_string(~S"slash <- [\\t]", slash: [parser: true])

  describe "slash in range works" do
    test "slash" do
      assert_parsed(slash("t"))
      assert_parsed(slash("\\"))
      refute_parsed(slash("a"))
    end
  end

  Pegasus.parser_from_string(~S"""
  STRINGLITERALSINGLE <- "\"" string_char* "\""
  string_char <- [^\\"\n]
  """,
  STRINGLITERALSINGLE: [parser: :string_literal])

  describe "string literal works" do
    test "optional, not used" do
      assert_parsed(string_literal(~S("string_literal")))
    end
  end
end
