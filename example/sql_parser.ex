defmodule Pegasus.Example.SqlParser do
  @moduledoc """
  A simple SQL parser.
  """
  require Pegasus
  import NimbleParsec

  @options [
    # Tagged Productions
    StatementSelect: [tag: :select],
    SelectList: [tag: :select_list],
    SelectTarget: [tag: :select_target],
    StatementSubquery: [tag: :subquery],
    Identifier: [tag: :identifier],
    PredicateGroupBy: [tag: :group_by],

    # Constants
    ConstantInteger: [tag: :constant, collect: true],
    ConstantString: [tag: :constant, collect: true],

    # Tagged tokens are used as defined options on a node.
    TokenDistinct: [tag: :distinct],

    # Ignore Tokens
    Spacing: [ignore: true],
    TokenComma: [ignore: true],
    TokenSemiColon: [ignore: true],
    TokenOpenParen: [ignore: true],
    TokenCloseParen: [ignore: true],
    TokenSelect: [ignore: true],
    TokenFrom: [ignore: true],
    TokenGroupBy: [ignore: true],
  ]

  Pegasus.parser_from_string(
    """
    SQL <- Statement

    Statement <- StatementSelect Spacing TokenSemiColon

    StatementSelect <-
      Spacing TokenSelect
      (Spacing TokenDistinct Spacing)?
      Spacing SelectList
      Spacing TokenFrom
      Spacing SelectTarget
      (Spacing PredicateGroupBy)?

    SelectList <- TokenStar / Sequence

    SelectTarget <- Identifier / StatementSubquery

    StatementSubquery <- TokenOpenParen StatementSelect TokenCloseParen

    # Its probably better to use a new node but using this as an option
    # is probably fine.
    PredicateGroupBy <- TokenGroupBy Spacing Sequence

    Sequence <- SequenceElement ( Spacing? TokenComma Spacing? Sequence )*

    SequenceElement <- Identifier / ConstantString / ConstantInteger

    Identifier      <- < IdentStart IdentCont* > Spacing
    IdentStart      <- [a-zA-Z_]
    IdentCont       <- IdentStart / [0-9]

    # Tokens
    TokenDistinct   <- < [Dd][Ii][Ss][Tt][Ii][Nn][Cc][Tt] >
    TokenFrom       <- < [Ff][Rr][Oo][Mm] >
    TokenGroupBy    <- < [Gg][Rr][Oo][Uu][Pp] > Spacing < [Bb][Yy] >
    TokenSelect     <- < [Ss][Ee][Ll][Ee][Cc][Tt] >

    TokenSemiColon  <- ";"
    TokenComma      <- ","
    TokenStar       <- "*"
    TokenOpenParen  <- "("
    TokenCloseParen <- ")"

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

  defparsec :parse, parsec(:SQL)
end
