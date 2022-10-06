defmodule PegasusTest do
  use ExUnit.Case, async: true

  require Pegasus
  import PegasusTest.Case

  Pegasus.parser_from_string("char_range <- [a-z]")

  describe "char_range works" do
    test "char_range" do
      assert_parsed(char_range("a"))
      refute_parsed(char_range("A"))
    end
  end

  Pegasus.parser_from_string("literal <- 'foo'")

  describe "literal works" do
    test "literal" do
      assert_parsed(literal("foo"))
      refute_parsed(literal("bar"))
    end
  end

  Pegasus.parser_from_string("sequence <- 'foo' 'bar'")

  describe "sequence works" do
    test "sequence" do
      assert_parsed(sequence("foobar"))
      refute_parsed(sequence("foo"))
    end
  end

  Pegasus.parser_from_string("lookahead <- &'f' 'foo'")

  describe "lookahead works" do
    test "lookahead" do
      assert_parsed(lookahead("foo"))
    end
  end

  Pegasus.parser_from_string("lookahead_not <- !'aaa' [a-z][a-z][a-z]")

  describe "lookahead_not works" do
    test "lookahead_not" do
      assert_parsed(lookahead_not("aab"))
      refute_parsed(lookahead_not("aaa"))
    end
  end

  Pegasus.parser_from_string("optional <- 'foo' 'bar'?")

  describe "optional works" do
    test "optional" do
      assert_parsed(optional("foo"))
      assert_parsed(optional("foobar"))
      refute_parsed(optional("funbar"))
      assert {:ok, ["foo"], "baz", _, _, _} = optional("foobaz")
    end
  end

  Pegasus.parser_from_string("repeat <- 'foo' 'bar'*")

  describe "repeat works" do
    test "repeat" do
      assert_parsed(repeat("foo"))
      assert_parsed(repeat("foobar"))
      assert_parsed(repeat("foobarbar"))
      refute_parsed(repeat("funbar"))
    end
  end

  Pegasus.parser_from_string("times <- 'foo' 'bar'+")

  describe "times works" do
    test "times" do
      refute_parsed(times("foo"))
      assert_parsed(times("foobar"))
      assert_parsed(times("foobarbar"))
      refute_parsed(times("funbar"))
    end
  end

  Pegasus.parser_from_string("""
  identifier <- 'foo' IDENTIFIER  # plus a comment, why not
  IDENTIFIER <- 'bar'
  """)

  describe "identifiers work" do
    test "identifier" do
      assert_parsed(identifier("foobar"))
      refute_parsed(identifier("foo"))
      refute_parsed(identifier("bar"))
    end
  end

  Pegasus.parser_from_string("choice <- 'foo' / 'bar'")

  describe "choice works" do
    test "choice" do
      assert_parsed(choice("foo"))
      assert_parsed(choice("bar"))
      refute_parsed(choice("baz"))
    end
  end

  Pegasus.parser_from_string("dumb_parens <- ('foo' [a-z]) 'bar' ")

  describe "dumb parens work" do
    test "dumb_parens" do
      assert_parsed(dumb_parens("fooabar"))
      refute_parsed(dumb_parens("fooZbar"))
      refute_parsed(dumb_parens("foo"))
      refute_parsed(dumb_parens("fooa"))
      refute_parsed(dumb_parens("bar"))
    end
  end

  Pegasus.parser_from_string("times_parens <- ('foo' [a-z])+ 'bar' ")

  describe "smart parens work" do
    test "with times" do
      assert_parsed(times_parens("fooabar"))
      assert_parsed(times_parens("fooafooabar"))
      assert_parsed(times_parens("fooafooafooabar"))
      refute_parsed(times_parens("bar"))
    end
  end

  Pegasus.parser_from_string("begin_end <- < 'foo' [a-z] > 'bar' ")

  describe "begin-end works" do
    test "to group" do
      assert_parsed(begin_end("fooabar"))
      refute_parsed(begin_end("bar"))
    end
  end

  Pegasus.parser_from_string("dot <- 'foo' .")

  describe "dot works" do
    test "dot" do
      assert_parsed(dot("fooa"))
      refute_parsed(dot("foba"))
      refute_parsed(dot("foo"))
    end
  end

  describe "post_traverse settings work" do
    Pegasus.parser_from_string("post_traverse_ungrouped <- 'foo' [a-z]",
      post_traverse_ungrouped: {:post_traverse_ungrouped, []}
    )

    defp post_traverse_ungrouped("", [?a, "foo"], context, {1, 0}, 4) do
      {"", [], Map.put(context, :parsed, true)}
    end

    test "ungrouped content is presented as a list" do
      result = assert_parsed(post_traverse_ungrouped("fooa"))
      assert {:ok, [], "", %{parsed: true}, _, _} = result
    end

    Pegasus.parser_from_string("post_traverse_grouped <- ('foo' [a-z])",
      post_traverse_grouped: {:post_traverse_grouped, [:test]}
    )

    defp post_traverse_grouped("", ["fooa"], context, {1, 0}, 4, :test) do
      {"", [], Map.put(context, :parsed, true)}
    end

    test "grouped content is merged" do
      result = assert_parsed(post_traverse_grouped("fooa"))
      assert {:ok, [], "", %{parsed: true}, _, _} = result
    end

    Pegasus.parser_from_string("post_traverse_tagged <- <'foo' [a-z]> 'bar'",
      post_traverse_tagged: {:post_traverse_tagged, [:test]}
    )

    defp post_traverse_tagged("", ["fooa"], context, {1, 0}, 4, :test) do
      {"", [], Map.put(context, :parsed, true)}
    end

    @tag [skip: true]
    test "tagged content is merged and isolated" do
      result = assert_parsed(post_traverse_tagged("fooabar"))
      assert {:ok, [], "", %{parsed: true}, _, _} = result
    end
  end
end
