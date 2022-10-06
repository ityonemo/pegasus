defmodule PegasusTest.ComponentsTest do
  # tests basic components in the PEG grammar
  use ExUnit.Case, async: true

  alias Pegasus.Components

  import NimbleParsec
  import PegasusTest.Case

  for component <- ~w(end_of_file end_of_line space comment spacing char range)a do
    defparsecp(component, apply(Components, component, []))
  end

  describe "end of file" do
    test "parses end of file" do
      assert_parsed(end_of_file(""))
    end

    test "fails if it's not eof" do
      refute_parsed(end_of_file("a"))
    end
  end

  describe "end of line" do
    test "parses end of line" do
      assert_parsed(end_of_line("\n"), ~c'\n')
      assert_parsed(end_of_line("\r"), ~c'\r')
      assert_parsed(end_of_line("\n\r"), ["\n\r"])
    end

    test "fails if it's not eol" do
      refute_parsed(end_of_line(""))
      refute_parsed(end_of_line("a"))
      refute_parsed(end_of_line("a\n"))
    end
  end

  describe "space" do
    test "parses spaces" do
      assert_parsed(space(" "), ~c' ')
      assert_parsed(space("\t"), ~c'\t')
      assert_parsed(space("\n"), ~c'\n')
      assert_parsed(space("\n\r"), ["\n\r"])
    end

    test "fails non-spaces" do
      refute_parsed(space(""))
      refute_parsed(space("a"))
      refute_parsed(space("a "))
      refute_parsed(space("a\t"))
    end
  end

  describe "comment" do
    test "parses end of line comments" do
      assert_parsed(comment("# this is a comment\n"))
      assert_parsed(comment("# this is a # comment\n"))
      assert_parsed(comment("# windows comments\n\r"))
    end

    test "fails comments that are eof'd" do
      refute_parsed(comment("# this comment fails"))
    end

    test "fails non-comments" do
      refute_parsed(comment("a# comment\n"))
    end
  end

  describe "spacing" do
    test "parses spaces" do
      assert_parsed(spacing(" "))
      assert_parsed(spacing("  "))
      assert_parsed(spacing(" \t"))
    end

    test "parses comments" do
      assert_parsed(spacing("# comment\n"))
      assert_parsed(spacing("# comment\n# comment2\n"))
    end

    test "parses space then comments" do
      assert_parsed(spacing(" #comment\n"))
    end

    test "parses nothing" do
      assert_parsed(spacing(""))
    end

    test "fails non-space, non-comments" do
      refute_parsed(spacing("foo"))
    end
  end

  describe "char" do
    test "parses basic characters" do
      assert_parsed(char(" "), ~C' ')
      assert_parsed(char("f"), ~C'f')
      assert_parsed(char("A"), ~C'A')
    end

    test "parses escaped values" do
      assert_parsed(char(~S"\a"), [~c'\a'])
      assert_parsed(char(~S"\b"), [~c'\b'])
      assert_parsed(char(~S"\n"), [~c'\n'])
      assert_parsed(char(~S"\f"), [~c'\f'])
      assert_parsed(char(~S"\e"), [~c'\e'])
      assert_parsed(char(~S"\r"), [~c'\r'])
      assert_parsed(char(~S"\t"), [~c'\t'])
      assert_parsed(char(~S"\v"), [~c'\v'])

      assert_parsed(char(~S(\')), [~C(')])
      assert_parsed(char(~S(\")), [~C(")])
      assert_parsed(char(~S(\[)), [~C([)])
      assert_parsed(char(~S(\])), [~C(])])
      assert_parsed(char(~S(\-)), [~C(-)])
      # \\ -> '\'
      assert_parsed(char(<<92, 92>>), [[92]])
    end

    test "parses octal values" do
      assert_parsed(char(~S(\123)), [0o123])
      assert_parsed(char(~S(\77)), [0o77])
      assert_parsed(char(~S(\7)), [0o7])
    end

    test "fails when nothing" do
      refute_parsed(char(""))
    end
  end

  describe "range" do
    test "correctly produces a range" do
      assert_parsed(range(~S(a-z)), [?a..?z])
    end

    test "correctly produces a range with octal escape" do
      assert_parsed(range(~S(\123-Z)), [0o123..?Z])
    end

    test "correctly parses a single char" do
      assert_parsed(range(~S(a)), [?a])
    end

    test "correctly parses a single escaped char" do
      assert_parsed(range(~S(\123)), [0o123])
    end
  end
end
