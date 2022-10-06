defmodule PegasusTest.RegressionTest do
  use ExUnit.Case, async: true

  require Pegasus
  import PegasusTest.Case

  Pegasus.parser_from_string(~S"slash <- [\\t]")

  describe "slash in range works" do
    test "slash" do
      assert_parsed(slash("t"))
      assert_parsed(slash("\\"))
      refute_parsed(slash("a"))
    end
  end
end
