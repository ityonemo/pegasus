# Advanced Examples

This guide demonstrates advanced Pegasus patterns from real-world parsers.

## Vendored Grammar Files

Use `parser_from_file/2` when you have a reference PEG grammar vendored into your codebase. This is common when implementing a parser for an established format or language that has an official PEG specification:

```elixir
defmodule MyParser do
  require Pegasus

  # Grammar vendored from an upstream specification
  @external_resource Path.join(__DIR__, "grammar/grammar.peg")

  Pegasus.parser_from_file(
    Path.join(__DIR__, "grammar/grammar.peg"),
    @parser_options
  )
end
```

Using `@external_resource` ensures the module recompiles when the grammar file changes.

This approach keeps the authoritative grammar separate from your Elixir code, making it easier to update when the upstream specification changes.

## Dynamic Option Generation

When you have many similar rules, generate options programmatically:

```elixir
defmodule MyParser do
  require Pegasus

  # Keywords that become tokens
  @keywords ~w[if else while for return]a
  @keyword_options Enum.map(@keywords, fn kw ->
    {:"KEYWORD_#{kw}", [token: kw]}
  end)

  # Operators with position tracking
  @operators %{PLUS: :+, MINUS: :-, STAR: :*, SLASH: :/}
  @operator_options Enum.map(@operators, fn {name, op} ->
    {name, [token: op, start_position: true]}
  end)

  # Collected tokens
  @collected ~w[INTEGER FLOAT IDENTIFIER]a
  @collected_options Enum.map(@collected, fn name ->
    {name, [collect: true, post_traverse: {:parse_token, [name]}]}
  end)

  @parser_options [
    root: [parser: true]
  ] ++ @keyword_options ++ @operator_options ++ @collected_options

  Pegasus.parser_from_string(@grammar, @parser_options)
end
```

## Building AST Nodes with Structs

Define structs for your AST nodes:

```elixir
defmodule MyParser.Function do
  defstruct [
    :name,
    :params,
    :return_type,
    :body,
    :location,
    public: false,
    inline: false
  ]
end
```

Use post-traverse to build them:

```elixir
defmodule MyParser do
  require Pegasus
  alias MyParser.Function

  Pegasus.parser_from_string("""
    function <- 'pub'? 'inline'? 'fn' identifier params return_type? block
    identifier <- [a-zA-Z_] [a-zA-Z0-9_]*
    params <- '(' param_list? ')'
    param_list <- param (',' param)*
    param <- identifier ':' type
    return_type <- '->' type
    type <- identifier
    block <- '{' statement* '}'
    statement <- [^}]*
  """,
    function: [parser: true, tag: true, start_position: true,
               post_traverse: {Function, :post_traverse, []}],
    identifier: [collect: true],
    params: [tag: true],
    return_type: [tag: true],
    block: [tag: true]
  )
end

defmodule MyParser.Function do
  # ... struct definition ...

  def post_traverse(rest, [{:function, [start | args]} | rest_args], context, _, _) do
    func = parse(args, %__MODULE__{})
    func = %{func | location: {start.line, start.column}}
    {rest, [func | rest_args], context}
  end

  defp parse([:pub | rest], func), do: parse(rest, %{func | public: true})
  defp parse([:inline | rest], func), do: parse(rest, %{func | inline: true})
  defp parse([:fn, name | rest], func), do: parse(rest, %{func | name: name})
  defp parse([{:params, params} | rest], func), do: parse(rest, %{func | params: params})
  defp parse([{:return_type, [:"->", type]} | rest], func), do: parse(rest, %{func | return_type: type})
  defp parse([{:block, body}], func), do: %{func | body: body}
  defp parse([], func), do: func
end
```

## Operator Precedence with Shunting-Yard

PEG grammars don't directly express operator precedence. Implement it with post-traverse:

```elixir
defmodule ExprParser do
  require Pegasus

  Pegasus.parser_from_string("""
    expr <- term (operator term)*
    term <- number / '(' expr ')'
    operator <- '+' / '-' / '*' / '/'
    number <- [0-9]+
  """,
    expr: [parser: true, tag: :Expr, post_traverse: {__MODULE__, :build_tree, []}],
    operator: [collect: true],
    number: [collect: true, post_traverse: {:to_integer, []}]
  )

  defp to_integer(rest, [num], context, _, _) do
    {rest, [String.to_integer(num)], context}
  end

  # Operator precedence (higher = binds tighter)
  @precedence %{"*" => 2, "/" => 2, "+" => 1, "-" => 1}

  def build_tree(rest, [{:Expr, args} | rest_args], context, _, _) do
    tree = shunting_yard(args, [], [])
    {rest, [tree | rest_args], context}
  end

  # Shunting-yard algorithm
  defp shunting_yard([], [], [result]), do: result
  defp shunting_yard([], [op | ops], output) do
    shunting_yard([], ops, apply_op(op, output))
  end

  defp shunting_yard([term | rest], ops, output) when is_integer(term) do
    shunting_yard(rest, ops, [term | output])
  end

  defp shunting_yard([op | rest], [], output) do
    shunting_yard(rest, [op], output)
  end

  defp shunting_yard([op | rest], [top | ops], output) do
    if @precedence[top] >= @precedence[op] do
      shunting_yard([op | rest], ops, apply_op(top, output))
    else
      shunting_yard(rest, [op, top | ops], output)
    end
  end

  defp apply_op(op, [b, a | rest]) do
    [{String.to_atom(op), a, b} | rest]
  end
end

ExprParser.expr("1+2*3")
# => {:ok, [{:+, 1, {:*, 2, 3}}], "", ...}
```

## Context for Accumulating State

Use the parser context to collect information across the entire parse:

```elixir
defmodule DocParser do
  require Pegasus

  defstruct comments: [], imports: []

  Pegasus.parser_from_string("""
    root <- (comment / import / statement)*
    comment <- '//' (!'\n' .)*
    import <- 'import' ws path
    path <- [a-zA-Z/]+
    statement <- (!'\n' .)* '\n'
    ws <- [ \t]+
  """,
    root: [parser: :parse],
    comment: [tag: true, post_traverse: {:collect_comment, []}],
    import: [tag: true, post_traverse: {:collect_import, []}],
    path: [collect: true],
    ws: [ignore: true],
    statement: [ignore: true]
  )

  # Initialize context
  def parse(input) do
    case parser(input, context: %__MODULE__{}) do
      {:ok, _, "", context, _, _} ->
        {:ok, %{context | comments: Enum.reverse(context.comments),
                         imports: Enum.reverse(context.imports)}}
      error -> error
    end
  end

  defp collect_comment(rest, [{:comment, chars} | args], context, _, _) do
    comment = chars |> tl() |> tl() |> List.to_string()
    {rest, args, %{context | comments: [comment | context.comments]}}
  end

  defp collect_import(rest, [{:import, [:import, path]} | args], context, _, _) do
    {rest, args, %{context | imports: [path | context.imports]}}
  end
end
```

## Location Tracking for Error Messages

Track source locations for better error reporting:

```elixir
defmodule LocatedParser do
  require Pegasus

  defmodule Token do
    defstruct [:type, :value, :line, :column]
  end

  Pegasus.parser_from_string("""
    tokens <- token*
    token <- keyword / identifier / number / ws
    keyword <- 'if' / 'else' / 'while'
    identifier <- [a-zA-Z_] [a-zA-Z0-9_]*
    number <- [0-9]+
    ws <- [ \t\n]+
  """,
    tokens: [parser: true],
    keyword: [start_position: true, collect: true,
              post_traverse: {:make_token, [:keyword]}],
    identifier: [start_position: true, collect: true,
                 post_traverse: {:make_token, [:identifier]}],
    number: [start_position: true, collect: true,
             post_traverse: {:make_token, [:number]}],
    ws: [ignore: true]
  )

  defp make_token(rest, [value, pos | args], context, _, _, type) do
    token = %Token{
      type: type,
      value: value,
      line: pos.line,
      column: pos.column
    }
    {rest, [token | args], context}
  end
end
```

## Combining with Custom NimbleParsec Combinators

Use `:alias` to integrate custom combinators:

```elixir
defmodule UnicodeParser do
  require Pegasus
  import NimbleParsec

  # Custom combinator for Unicode categories
  defcombinatorp :unicode_letter,
    utf8_char([?a..?z, ?A..?Z, 0x00C0..0x00FF, 0x0100..0x017F])

  defcombinatorp :unicode_digit,
    utf8_char([?0..?9, 0x0660..0x0669, 0x06F0..0x06F9])

  Pegasus.parser_from_string("""
    identifier <- letter (letter / digit)*
    letter <- [a-zA-Z]
    digit <- [0-9]
  """,
    identifier: [parser: true, collect: true],
    letter: [alias: :unicode_letter],
    digit: [alias: :unicode_digit]
  )
end
```

## SQL Parser Example

A complete example showing tagged rules, post-traverse for AST building, and ignored tokens:

```elixir
defmodule SQLParser do
  require Pegasus

  @options [
    # Entry point
    statement: [parser: true],

    # AST nodes with post-traverse
    select: [tag: "select", post_traverse: {:build_select, []}],
    where: [tag: "where"],
    from: [tag: "from"],

    # Binary expressions
    binary_expr: [tag: "binary", post_traverse: {:build_binary, []}],

    # Terminals
    identifier: [collect: true, tag: "identifier"],
    integer: [collect: true, post_traverse: {:to_int, []}],
    string: [collect: true],

    # Operators become tokens
    eq: [token: :=],
    and_op: [token: :and],
    or_op: [token: :or],

    # Ignored syntax
    ws: [ignore: true],
    comma: [ignore: true],
    semicolon: [ignore: true]
  ]

  Pegasus.parser_from_string("""
    statement <- ws select ws semicolon ws

    select <- 'SELECT' ws select_list ws from ws where?

    select_list <- '*' / expr_list
    expr_list <- expr (ws comma ws expr)*

    from <- 'FROM' ws identifier

    where <- 'WHERE' ws expr

    expr <- binary_expr / term
    binary_expr <- term ws operator ws expr
    term <- identifier / integer / string

    operator <- eq / and_op / or_op
    eq <- '='
    and_op <- 'AND'
    or_op <- 'OR'

    identifier <- [a-zA-Z_] [a-zA-Z0-9_]*
    integer <- [0-9]+
    string <- ['] (!['] .)* [']

    ws <- [ \\t\\n]*
    comma <- ','
    semicolon <- ';'
  """, @options)

  defp to_int(rest, [num], context, _, _) do
    {rest, [String.to_integer(num)], context}
  end

  defp build_select(rest, [{_, args} | rest_args], context, _, _) do
    ast = %{
      type: :select,
      columns: extract_columns(args),
      from: extract_from(args),
      where: extract_where(args)
    }
    {rest, [ast | rest_args], context}
  end

  defp build_binary(rest, [{_, [left, op, right]} | rest_args], context, _, _) do
    ast = %{type: :binary, operator: op, left: left, right: right}
    {rest, [ast | rest_args], context}
  end

  # Helper functions...
  defp extract_columns(args), do: # ...
  defp extract_from(args), do: # ...
  defp extract_where(args), do: # ...
end
```

## Modular Parser Organization

For large parsers, organize into modules by grammar section:

```
lib/
  my_parser.ex           # Main module with parser_from_file
  my_parser/
    expression.ex        # Expression AST and post_traverse
    statement.ex         # Statement AST and post_traverse
    function.ex          # Function AST and post_traverse
    types.ex             # Type AST and post_traverse
    collected.ex         # Token collection handlers
grammar/
  grammar.peg            # The PEG grammar
```

Each module handles its own AST nodes:

```elixir
# lib/my_parser/expression.ex
defmodule MyParser.Expression do
  defstruct [:operator, :left, :right, :location]

  def post_traverse(rest, [{:Expr, args} | rest_args], context, _, _) do
    expr = build(args)
    {rest, [expr | rest_args], context}
  end

  defp build(args) do
    # ...
  end
end
```

And the main module references them:

```elixir
# lib/my_parser.ex
defmodule MyParser do
  require Pegasus
  alias MyParser.{Expression, Statement, Function}

  @parser_options [
    expr: [tag: :Expr, post_traverse: {Expression, :post_traverse, []}],
    statement: [tag: :Statement, post_traverse: {Statement, :post_traverse, []}],
    function: [tag: :Function, post_traverse: {Function, :post_traverse, []}]
  ]

  Pegasus.parser_from_file("grammar/grammar.peg", @parser_options)
end
```

## Tips for Large Parsers

1. **Start with the grammar**: Get the PEG grammar working before adding options
2. **Add options incrementally**: Start with `parser: true` on the entry point, then add more
3. **Test post-traverse in isolation**: Write unit tests for transformation functions
4. **Use `:tag` liberally**: Tagged output makes pattern matching in post-traverse easier
5. **Accumulate in reverse**: Prepend to lists in post-traverse, reverse at the end
6. **Handle all variants**: Use multiple function clauses to match different parse shapes
7. **Track locations early**: Add `start_position: true` before you need it
