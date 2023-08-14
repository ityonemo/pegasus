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
  hex <- [0-9a-fA-F]

  char_escape
    <- "\\x" hex hex
     / "\\u{" hex+ "}"
     / "\\" [nr\\t'"]
  """, char_escape: [parser: true])

  describe "char_escape" do
    test "works with hex" do
      assert_parsed(char_escape(~S"\x00"))
    end

    test "works with u" do
      assert_parsed(char_escape(~S"\u{0a0a}"))
    end

    test "works with \\n" do
      assert_parsed(char_escape(~S"\n"))
    end

    test "works with \\r" do
      assert_parsed(char_escape(~S"\r"))
    end

    test "works with \\\\" do
      assert_parsed(char_escape(~S"\\"))
    end

    test "works with \\t" do
      assert_parsed(char_escape(~S"\t"))
    end

    test "works with \\'" do
      assert_parsed(char_escape(~S"\'"))
    end

    test "works with \\\"" do
      assert_parsed(char_escape(~S(\")))
    end
  end

  Pegasus.parser_from_string(
    ~S"""
    STRINGLITERALSINGLE <- "\"" string_char* "\""
    string_char <- [^\\"\n]
    """,
    STRINGLITERALSINGLE: [parser: :string_literal]
  )

  describe "string literal works" do
    test "optional, not used" do
      assert_parsed(string_literal(~S("string_literal")))
    end
  end
end
