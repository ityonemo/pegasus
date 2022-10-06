Grammar         <- Spacing Definition+ EndOfFile

Definition      <- Identifier LEFTARROW Expression
Expression      <- Sequence ( SLASH Sequence )*
Sequence        <- Prefix*
Prefix          <- AND Action
                 / ( AND | NOT )? Suffix
Suffix          <- Primary ( QUERY / STAR / PLUS )?
Primary         <- Identifier !LEFTARROW
                 / OPEN Expression CLOSE
                 / Literal
                 / Class
                 / DOT
                 / Action
                 / BEGIN
                 / END

Identifier      <- < IdentStart IdentCont* > Spacing
IdentStart      <- [a-zA-Z_]
IdentCont       <- IdentStart / [0-9]
Literal         <- ['] < ( !['] Char  )* > ['] Spacing
                 / ["] < ( !["] Char  )* > ["] Spacing
Class           <- '[' < ( !']' Range )* > ']' Spacing
Range           <- Char '-' Char / Char
Char            <- '\\' [abefnrtv'"\[\]\\]
                 / '\\' [0-3][0-7][0-7]
                 / '\\' [0-7][0-7]?
                 / '\\' '-'
                 / !'\\' .
LEFTARROW       <- '<-' Spacing
SLASH           <- '/' Spacing
AND             <- '&' Spacing
NOT             <- '!' Spacing
QUERY           <- '?' Spacing
STAR            <- '*' Spacing
PLUS            <- '+' Spacing
OPEN            <- '(' Spacing
CLOSE           <- ')' Spacing
DOT             <- '.' Spacing
Spacing         <- ( Space / Comment )*
Comment         <- '#' ( !EndOfLine . )* EndOfLine
Space           <- ' ' / '\t' / EndOfLine
EndOfLine       <- '\r\n' / '\n' / '\r'
EndOfFile       <- !.
Action          <- '{' < [^}]* > '}' Spacing
BEGIN           <- '<' Spacing
END             <- '>' Spacing