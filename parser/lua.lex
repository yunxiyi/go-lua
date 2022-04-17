/* scanner for a lua-like language */

%{
	package lua

	import "fmt"
	import "flag"
    import "strings"
%}

w              [ \t\v\a]+
o              [ \t\v\a]*
name           [_a-zA-Z][_a-zA-Z0-9]*
n              [0-9]+
exp            [Ee][+-]?{n}
number         [-+]?[0-9]+[.]?[0-9]+([Ee][+-]?[0-9]+)?



%x XLONGSTRING
%x XSHORTCOMMENT
%x XLONGCOMMENT
%x XSTRINGQ
%x XSTRINGA

%%

^#!.*          { /*  */};
and            {return TK_AND};
break          return TK_BREAK;
do             return TK_DO;
else           return TK_ELSE;
elseif         return TK_ELSEIF;
end            return TK_END;
false          return TK_FALSE;
for            return TK_FOR;
function       return TK_FUNCTION;
if             return TK_IF;
in             return TK_IN;
local          return TK_LOCAL;
nil            return TK_NIL;
not            return TK_NOT;
or             return TK_OR;
repeat         return TK_REPEAT;
return         return TK_RETURN;
then           return TK_THEN;
true           return TK_TRUE;
until          return TK_UNTIL;
while          return TK_WHILE;

({n}|{n}[.]{n}){exp}?       return TK_NUMBER;
{name}         return TK_NAME;

"--[["         BEGIN( XLONGCOMMENT );
"--"           yymore(); BEGIN( XSHORTCOMMENT );

"[["({o}\n)?   yymore();BEGIN( XLONGSTRING );

{w}            return TK_WHITESPACE;
"..."          return TK_DOTS;
".."           return TK_CONCAT;
"=="           return TK_EQ;
">="           return TK_GE;
"<="           return TK_LE;
"~="           return TK_NE;
"-"            return int([]byte(yytext)[0]);
"+"            return int([]byte(yytext)[0]);
"*"            return int([]byte(yytext)[0]);
"/"            return int([]byte(yytext)[0]);
"="            return int([]byte(yytext)[0]);
">"            return int([]byte(yytext)[0]);
"<"            return int([]byte(yytext)[0]);
"("            return int([]byte(yytext)[0]);
")"            return int([]byte(yytext)[0]);
"["            return int([]byte(yytext)[0]);
"]"            return int([]byte(yytext)[0]);
"{"            return int([]byte(yytext)[0]);
"}"            return int([]byte(yytext)[0]);
\n             return TK_NEWLINE;
\r             return TK_NEWLINE;
\"             yymore(); BEGIN(XSTRINGQ);
'              yymore(); BEGIN(XSTRINGA);
.              return int([]byte(yytext)[0]);

<XSTRINGQ>\"\"          yymore();
<XSTRINGQ>\"            BEGIN(0); return TK_STRING;
<XSTRINGQ>\\[abfnrtv]   yymore();
<XSTRINGQ>\\\n          yymore();
<XSTRINGQ>\\\"          yymore();
<XSTRINGQ>\\'           yymore();
<XSTRINGQ>\\"["         yymore();
<XSTRINGQ>\\"]"         yymore();
<XSTRINGQ>[\n|\r]       {    
                            fmt.Printf("unterminated string.\n");
                            BEGIN(0);
                            return TK_STRING;
                        }
<XSTRINGQ>.             yymore();


<XSTRINGA>''          yymore();
<XSTRINGA>'           BEGIN(0); return TK_STRING;
<XSTRINGA>\\[abfnrtv] yymore();
<XSTRINGA>\\\n        yymore();
<XSTRINGA>\\\"        yymore();
<XSTRINGA>\\'         yymore();
<XSTRINGA>\\"["       yymore();
<XSTRINGA>\\"]"       yymore();
<XSTRINGA>[\n|\r]     {     fmt.Printf("unterminated string.\n");
                            BEGIN(0);
                            return TK_STRING;
                        }
<XSTRINGA>.           yymore();


<XLONGSTRING>"]]"        BEGIN(0); return TK_LONGSTRING;
<XLONGSTRING>\n          yymore();
<XLONGSTRING>\r          yymore();
<XLONGSTRING>.           yymore();

<XSHORTCOMMENT>\n          BEGIN(0); return TK_SHORTCOMMENT;
<XSHORTCOMMENT>\r          BEGIN(0); return TK_SHORTCOMMENT;
<XSHORTCOMMENT>.           yymore();

<XLONGCOMMENT>"]]--"      BEGIN(0); return TK_LONGCOMMENT;
<XLONGCOMMENT>\n          yymore();
<XLONGCOMMENT>\r          yymore();
<XLONGCOMMENT>.           yymore();

%%

var lineNo, linePos int

func ParseLexer() {
	flag.Parse()
	if flag.NArg() > 0 {
		yyin, _ = os.Open(flag.Arg(0))
	} else {
		yyin = os.Stdin
	}
    lineNo = 1

	for tok := yylex(); tok > 0; tok = yylex() {
        
        if tok == TK_WHITESPACE  {
            linePos = linePos + len(yytext)
            continue
        }
        if tok == TK_NEWLINE{
            lineNo = lineNo + 1
            linePos = 0
            continue
        }
        fmt.Printf("%05d \t %05d \t %05d \t %-13.13s:  %s\n", tok, lineNo, linePos, TokenName(tok), yytext)
        linePos = linePos + len(yytext)
        newLineCnt := strings.Count(yytext, "\n")
        if newLineCnt > 0 {
            linePos = 0
        }
        lineNo = lineNo + strings.Count(yytext, "\n")
    }
}
