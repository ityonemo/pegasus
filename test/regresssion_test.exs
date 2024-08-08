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

  Pegasus.parser_from_string(~S"""
  ox80_oxBF <- [\200-\277]
  oxF4 <- '\364'
  ox80_ox8F <- [\200-\217]
  oxF1_oxF3 <- [\361-\363]
  oxF0 <- '\360'
  ox90_0xBF <- [\220-\277]
  oxEE_oxEF <- [\356-\357]
  oxED <- '\355'
  ox80_ox9F <- [\200-\237]
  oxE1_oxEC <- [\341-\354]
  oxE0 <- '\340'
  oxA0_oxBF <- [\240-\277]
  oxC2_oxDF <- [\302-\337]

  mb_utf8_literal <-
    oxF4      ox80_ox8F ox80_oxBF ox80_oxBF
  / oxF1_oxF3 ox80_oxBF ox80_oxBF ox80_oxBF
  / oxF0      ox90_0xBF ox80_oxBF ox80_oxBF
  / oxEE_oxEF ox80_oxBF ox80_oxBF
  / oxED      ox80_ox9F ox80_oxBF
  / oxE1_oxEC ox80_oxBF ox80_oxBF
  / oxE0      oxA0_oxBF ox80_oxBF
  / oxC2_oxDF ox80_oxBF
  """, mb_utf8_literal: [parser: true])

  describe "utf-8 descriptor" do
    test "works" do
      assert_parsed(mb_utf8_literal("🚀"))
    end
  end

  Pegasus.parser_from_string(~S"""
  byte_range <- [\302-\304]
  """, byte_range: [parser: true])

  describe "single byte range" do
    test "works" do
      assert_parsed(byte_range(<<0o303>>))
    end
  end

  Pegasus.parser_from_string(~S"""
  octal_escape_three_digit  <- '\065'
  octal_escape_two_digit    <- '\65'
  octal_escape_one_digit    <- '\5'
  """, 
  octal_escape_three_digit: [parser: true],
  octal_escape_two_digit: [parser: true],
  octal_escape_one_digit: [parser: true])

  describe "octal escape" do
    test "works with a leading zero" do
      assert_parsed(octal_escape_three_digit("5"))
    end

    test "works with two digit" do
      assert_parsed(octal_escape_two_digit("5"))
    end

    test "works with one digit" do
      assert_parsed(octal_escape_one_digit(<<5>>))
    end
  end
end
