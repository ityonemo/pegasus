defmodule Pegasus.Example.Parser do
  @moduledoc """
  Parses a SQL statement into a simplistic AST.

  The output is an AST with nodes in the following format:
  ```
  %{
    "type" => <node_type>
    "opts" => [],
    "children" => [node()]
  }
  ```
  Where `opts` is any extra matadata associated with that particular node, such
  as an identifier's name or a SELECT statement's select list or the operator of
  a comparision expression.
  """
  require Pegasus
  require Logger

  import NimbleParsec

  @options [
    # Exported sub-parsers
    expression: [parser: true, export: true],

    # Post traversed nodes get transformed into proper AST nodes.
    # This happens either with the `terminal`, `generic` or node specific post
    # traversal function.
    ExpressionBinary: [tag: "expression_binary", post_traverse: :post_traverser],
    ExpressionFunCall: [tag: "fun_call", post_traverse: :post_traverser],
    Identifier: [tag: "identifier", post_traverse: :terminal_post_traverser],
    StatementSelect: [tag: "select", post_traverse: :statement_post_traverser],
    TableGet: [tag: "table_get", post_traverse: :post_traverser],
    TokenDynamic: [tag: "token_dynamic", post_traverse: :terminal_post_traverser],

    # Tagged Productions
    SelectList: [tag: "select_list"],
    StatementSubquery: [tag: "subquery"],
    PredicateGroupBy: [tag: "group_by"],
    PredicateWhere: [tag: "where"],

    # Constants
    ConstantInteger: [
      tag: "constant_integer",
      collect: true,
      post_traverse: :terminal_post_traverser
    ],
    ConstantString: [
      tag: "constant_string",
      collect: true,
      post_traverse: :terminal_post_traverser
    ],

    # These are node-level options.
    TokenDistinct: [tag: {:opt, "distinct"}],
    TokenEqual: [tag: {:opt, "operator"}],
    TokenAnd: [tag: {:opt, "operator"}],
    TokenOr: [tag: {:opt, "operator"}],
    TokenPlus: [tag: {:opt, "operator"}],
    SequenceGroupBy: [tag: {:opt, "group_by_list"}],

    # Ignore Tokens
    Spacing: [ignore: true],
    TokenComma: [ignore: true],
    TokenSemiColon: [ignore: true],
    TokenOpenParen: [ignore: true],
    TokenCloseParen: [ignore: true],
    TokenFrom: [ignore: true],
    TokenGroupBy: [ignore: true],
    TokenWhere: [ignore: true],
    TokenSelect: [ignore: true]
  ]

  Pegasus.parser_from_string(
    """
    # Exported top level parser.
    SQL <- Statement

    # Exported partial expression parser.
    # Lower-case the name here to allow for exporting into Elixir.
    expression <- Expression

    Statement <- StatementSelect Spacing TokenSemiColon

    StatementSelect <-
      Spacing TokenSelect
      (Spacing TokenDistinct Spacing)?
      Spacing SelectList
      Spacing TokenFrom
      Spacing SelectTarget
      (Spacing PredicateWhere)?
      (Spacing PredicateGroupBy)?

    SelectList <- TokenStar / Sequence

    SelectTarget <- TableGet / StatementSubquery

    TableGet <- Identifier

    StatementSubquery <- TokenOpenParen StatementSelect TokenCloseParen

    PredicateGroupBy <- TokenGroupBy Spacing SequenceGroupBy

    SequenceGroupBy <- Sequence

    PredicateWhere <- TokenWhere Spacing Expression Spacing

    Sequence <- Expression ( Spacing? TokenComma Spacing? Sequence )*

    Expression <-
      TokenOpenParen Spacing Expression Spacing TokenCloseParen
      / ExpressionBinary
      / Expr

    ExpressionBinary <-
      Expr Spacing Operator Spacing Expression
      #/ Expr (Spacing ExpressionBinaryRest)*

    ExpressionBinaryRest <-
      Operator Spacing ExpressionBinary

    Operator <-
      TokenEqual
      / TokenAnd
      / TokenOr
      / TokenPlus

    Expr <-
      ExpressionFunCall
      / ExpressionConstant

    ExpressionFunCall <-
      Identifier Spacing TokenOpenParen Spacing Expression Spacing TokenCloseParen

    ExpressionConstant <- 
      TokenDynamic
      / ConstantString
      / Identifier
      / ConstantInteger

    Identifier      <- < IdentStart IdentCont* > Spacing
    IdentStart      <- [a-zA-Z_\.]
    IdentCont       <- IdentStart / [0-9]

    # These are semi-keyword semi-constants that get defined at runtime.
    TokenDynamic <- TokenCurrentDate

    # Tokens
    TokenDistinct   <- < [Dd][Ii][Ss][Tt][Ii][Nn][Cc][Tt] >
    TokenFrom       <- < [Ff][Rr][Oo][Mm] >
    TokenGroupBy    <- < [Gg][Rr][Oo][Uu][Pp] > Spacing < [Bb][Yy] >
    TokenSelect     <- < [Ss][Ee][Ll][Ee][Cc][Tt] >
    TokenWhere      <- < [Ww][Hh][Ee][Rr][Ee] >
    TokenCurrentDate  <- < [Cc][Uu][Rr][Rr][Ee][Nn][Tt][_][Dd][Aa][Tt][Ee] >

    TokenSemiColon  <- ";"
    TokenComma      <- ","
    TokenStar       <- "*"
    TokenOpenParen  <- "("
    TokenCloseParen <- ")"
    TokenEqual      <- "="
    TokenPlus       <- "+"
    TokenAnd        <- < [Aa][Nn][Dd] >
    TokenOr         <- < [Oo][Rr] >

    # Constants
    ConstantInteger <- [0-9]*
    ConstantString  <- ['] < ( !['] . )* > [']

    # Misc
    Spacing         <- ( Space / Comment )*
    Space           <- ' ' / '\t' / EndOfLine
    Comment         <- '//' ( !EndOfLine . )* EndOfLine
    EndOfLine       <- '\r\n' / '\n' / '\r'
    """,
    @options
  )

  defparsec(:parse, parsec(:SQL))

  @doc "Prints the AST in a relativly reasonable format."
  def print(ast) do
    Logger.debug(inspect(ast, pretty: true, width: 150))
  end

  @doc """
  Prints the AST in a relativly reasonable format with the line and file of the
  caller.
  """
  def print(ast, file_caller, line_caller) do
    Logger.debug("#{file_caller}:#{line_caller} #{inspect(ast, pretty: true, width: 150)}")
  end

  # The generic post_traverser is a helper to form a generic node from a parse node.
  # This basically just flattens the parse node into a consistent AST structure.
  defp post_traverser(rest, args, context, _line, _offset) do
    [{node_type, node}] = args
    {opts, children} = reduce_parse_node(node, {[], []})

    node = %{
      "type" => node_type,
      "opts" => opts,
      "children" => Enum.reverse(children)
    }

    {rest, [node], context}
  end

  defp reduce_parse_node([], acc), do: acc

  defp reduce_parse_node([{{:opt, type}, opt} | rest], {opts_acc, children_acc}) do
    reduce_parse_node(rest, {[{type, opt} | opts_acc], children_acc})
  end

  defp reduce_parse_node([child | rest], {opts_acc, children_acc}) do
    reduce_parse_node(rest, {opts_acc, [child | children_acc]})
  end

  # The statement_post_traverser transforms statement parse nodes into AST node, as they
  # are a bit more complex.
  defp statement_post_traverser(rest, [{"select", node_opts}] = args, context, _, _) do
    group_by = :proplists.get_value("group_by", node_opts, nil)

    if group_by !== nil do
      gbagg_post_traverser(rest, args, context)
    else
      select_post_traverser(rest, args, context)
    end
  end

  # Group By Aggregate post traversal node.
  # Strips the group by, post-traverses on the select statement, then assembles the node.
  def gbagg_post_traverser(rest, [{"select", node_opts}], context) do
    node_opts_raw = List.keydelete(node_opts, "group_by", 0)
    select_traverser_input = [{"select", node_opts_raw}]
    {_, [ast_select], _} = select_post_traverser(rest, select_traverser_input, context)

    node_opts = :proplists.get_value("group_by", node_opts)
    {opts, _} = reduce_parse_node(node_opts, {[], []})
    ast_gbagg = %{
      "type" => "gbagg",
      "opts" => opts,
      "children" => [ast_select]
    }

    {rest, [ast_gbagg], context}
  end

  # Post traverse wrapper for SELECTs.
  defp select_post_traverser(rest, [{"select", node_opts}], context) do
    select_list = :proplists.get_value("select_list", node_opts)
    where = :proplists.get_value("where", node_opts, [])

    {opts, _} = reduce_parse_node(node_opts, {[], []})

    target =
      node_opts
      |> List.keydelete("select_list", 0)
      |> List.keydelete("where", 0)
      |> strip_optionals()

    ast_select = %{
      "type" => "select",
      "opts" => [{"select_list", select_list} | opts],
      "children" => target ++ where
    }

    {rest, [ast_select], context}
  end

  # The terminal post traverser is for simple "terminal" nodes,
  # which are nodes with no children and basically a constant interior.
  defp terminal_post_traverser(rest, args, context, _line, _offset) do
    [{type, [node_name]}] = args

    node = %{
      "type" => type,
      "opts" => [{"value", node_name}],
      "children" => []
    }

    {rest, [node], context}
  end

  # Removes optionals from a parse node.
  defp strip_optionals(list), do: strip_optionals(list, [])

  defp strip_optionals([], acc), do: Enum.reverse(acc)
  defp strip_optionals([{{:opt, _}, _} | rest], acc), do: strip_optionals(rest, acc)
  defp strip_optionals([head | rest], acc), do: strip_optionals(rest, [head | acc])
end
