%{
package lua

import (
  "github.com/yunxiyi/go-lua/ast"
)
%}
%type<stmts> chunk
%type<stmts> chunk1
%type<stmts> block
%type<stmt>  stat
%type<stmts> elseifs
%type<stmt>  laststat
%type<funcname> funcname
%type<funcname> funcname1
%type<exprlist> varlist
%type<expr> var
%type<namelist> namelist
%type<exprlist> exprlist
%type<expr> expr
%type<expr> string
%type<expr> prefixexp
%type<expr> functioncall
%type<expr> afunctioncall
%type<exprlist> args
%type<expr> function
%type<funcexpr> funcbody
%type<parlist> parlist
%type<expr> tableconstructor
%type<fieldlist> fieldlist
%type<field> field
%type<fieldsep> fieldsep

%union {
  token  ast.Token

  stmts    []ast.Stmt
  stmt     ast.Stmt

  funcname *ast.FuncName
  funcexpr *ast.FunctionExpr

  exprlist []ast.Expr
  expr   ast.Expr

  fieldlist []*ast.Field
  field     *ast.Field
  fieldsep  string

  namelist []string
  parlist  *ast.ParList
}

/* Reserved words */
/*
TK_EOF TK_AND TK_BREAK TK_DO TK_ELSE TK_ELSEIF TK_END TK_FALSE TK_FOR TK_FUNCTION TK_IF TK_IN TK_LOCAL TK_NIL TK_NOT TK_OR TK_REPEAT TK_RETURN TK_THEN TK_TRUE TK_UNTIL TK_WHILE 
TK_CONCAT TK_DOTS TK_EQ TK_GE TK_LE TK_NE TK_NUMBER TK_NAME TK_STRING TK_LONGSTRING TK_SHORTCOMMENT TK_LONGCOMMENT TK_WHITESPACE TK_NEWLINE TK_BADCHAR UNARY
*/
%token<token> TK_AND TK_BREAK TK_DO TK_ELSE TK_ELSEIF TK_END TK_FALSE TK_FOR TK_FUNCTION TK_IF TK_IN TK_LOCAL TK_NIL TK_NOT TK_OR TK_RETURN TK_REPEAT TK_THEN TK_TRUE TK_UNTIL TK_WHILE 
%token<token> TK_DOTS TK_CONCAT TK_LONGSTRING TK_SHORTCOMMENT TK_LONGCOMMENT TK_WHITESPACE TK_NEWLINE TK_BADCHAR UNARY

/* Literals */
%token<token> TK_EQ TK_NE TK_LE TK_GE TK_NAME TK_NUMBER TK_STRING T2Comma T3Comma '{' '('

/* Operarators */
%left TK_OR
%left TK_AND
%left '>' '<' TK_GE TK_LE TK_EQ TK_NE
%right T2Comma
%left '+' '-'
%left '*' '/' '%'
%right UNARY /* not # -(unary) */
%right '^'

%%

chunk: 
        chunk1 {
            $$ = $1
            if l, ok := yylex.(*Lexer); ok {
                l.Stmts = $$
            }
        } |
        chunk1 laststat {
            $$ = append($1, $2)
            if l, ok := yylex.(*Lexer); ok {
                l.Stmts = $$
            }
        } | 
        chunk1 laststat ';' {
            $$ = append($1, $2)
            if l, ok := yylex.(*Lexer); ok {
                l.Stmts = $$
            }
        }

chunk1: 
        {
            $$ = []ast.Stmt{}
        } |
        chunk1 stat {
            $$ = append($1, $2)
        } | 
        chunk1 ';' {
            $$ = $1
        }

block: 
        chunk {
            $$ = $1
        }

stat:
        varlist '=' exprlist {
            $$ = &ast.AssignStmt{Lhs: $1, Rhs: $3}
            $$.SetLine($1[0].Line())
        } |
        /* 'stat = functioncal' causes a reduce/reduce conflict */
        prefixexp {
            if _, ok := $1.(*ast.FuncCallExpr); !ok {
               yylex.(*Lexer).Error("parse error")
            } else {
              $$ = &ast.FuncCallStmt{Expr: $1}
              $$.SetLine($1.Line())
            }
        } |
        TK_DO block TK_END {
            $$ = &ast.DoBlockStmt{Stmts: $2}
            $$.SetLine($1.Pos.Line)
            $$.SetLastLine($3.Pos.Line)
        } |
        TK_WHILE expr TK_DO block TK_END {
            $$ = &ast.WhileStmt{Condition: $2, Stmts: $4}
            $$.SetLine($1.Pos.Line)
            $$.SetLastLine($5.Pos.Line)
        } |
        TK_REPEAT block TK_UNTIL expr {
            $$ = &ast.RepeatStmt{Condition: $4, Stmts: $2}
            $$.SetLine($1.Pos.Line)
            $$.SetLastLine($4.Line())
        } |
        TK_IF expr TK_THEN block elseifs TK_END {
            $$ = &ast.IfStmt{Condition: $2, Then: $4}
            cur := $$
            for _, elseif := range $5 {
                cur.(*ast.IfStmt).Else = []ast.Stmt{elseif}
                cur = elseif
            }
            $$.SetLine($1.Pos.Line)
            $$.SetLastLine($6.Pos.Line)
        } |
        TK_IF expr TK_THEN block elseifs TK_ELSE block TK_END {
            $$ = &ast.IfStmt{Condition: $2, Then: $4}
            cur := $$
            for _, elseif := range $5 {
                cur.(*ast.IfStmt).Else = []ast.Stmt{elseif}
                cur = elseif
            }
            cur.(*ast.IfStmt).Else = $7
            $$.SetLine($1.Pos.Line)
            $$.SetLastLine($8.Pos.Line)
        } |
        TK_FOR TK_NAME '=' expr ',' expr TK_DO block TK_END {
            $$ = &ast.NumberForStmt{Name: $2.Str, Init: $4, Limit: $6, Stmts: $8}
            $$.SetLine($1.Pos.Line)
            $$.SetLastLine($9.Pos.Line)
        } |
        TK_FOR TK_NAME '=' expr ',' expr ',' expr TK_DO block TK_END {
            $$ = &ast.NumberForStmt{Name: $2.Str, Init: $4, Limit: $6, Step:$8, Stmts: $10}
            $$.SetLine($1.Pos.Line)
            $$.SetLastLine($11.Pos.Line)
        } |
        TK_FOR namelist TK_IN exprlist TK_DO block TK_END {
            $$ = &ast.GenericForStmt{Names:$2, Exprs:$4, Stmts: $6}
            $$.SetLine($1.Pos.Line)
            $$.SetLastLine($7.Pos.Line)
        } |
        TK_FUNCTION funcname funcbody {
            $$ = &ast.FuncDefStmt{Name: $2, Func: $3}
            $$.SetLine($1.Pos.Line)
            $$.SetLastLine($3.LastLine())
        } |
        TK_LOCAL TK_FUNCTION TK_NAME funcbody {
            $$ = &ast.LocalAssignStmt{Names:[]string{$3.Str}, Exprs: []ast.Expr{$4}}
            $$.SetLine($1.Pos.Line)
            $$.SetLastLine($4.LastLine())
        } | 
        TK_LOCAL namelist '=' exprlist {
            $$ = &ast.LocalAssignStmt{Names: $2, Exprs:$4}
            $$.SetLine($1.Pos.Line)
        } |
        TK_LOCAL namelist {
            $$ = &ast.LocalAssignStmt{Names: $2, Exprs:[]ast.Expr{}}
            $$.SetLine($1.Pos.Line)
        }

elseifs: 
        {
            $$ = []ast.Stmt{}
        } | 
        elseifs TK_ELSEIF expr TK_THEN block {
            $$ = append($1, &ast.IfStmt{Condition: $3, Then: $5})
            $$[len($$)-1].SetLine($2.Pos.Line)
        }

laststat:
        TK_RETURN {
            $$ = &ast.ReturnStmt{Exprs:nil}
            $$.SetLine($1.Pos.Line)
        } |
        TK_RETURN exprlist {
            $$ = &ast.ReturnStmt{Exprs:$2}
            $$.SetLine($1.Pos.Line)
        } |
        TK_BREAK  {
            $$ = &ast.BreakStmt{}
            $$.SetLine($1.Pos.Line)
        }

funcname: 
        funcname1 {
            $$ = $1
        } |
        funcname1 ':' TK_NAME {
            $$ = &ast.FuncName{Func:nil, Receiver:$1.Func, Method: $3.Str}
        }

funcname1:
        TK_NAME {
            $$ = &ast.FuncName{Func: &ast.IdentExpr{Value:$1.Str}}
            $$.Func.SetLine($1.Pos.Line)
        } | 
        funcname1 '.' TK_NAME {
            key:= &ast.StringExpr{Value:$3.Str}
            key.SetLine($3.Pos.Line)
            fn := &ast.AttrGetExpr{Object: $1.Func, Key: key}
            fn.SetLine($3.Pos.Line)
            $$ = &ast.FuncName{Func: fn}
        }

varlist:
        var {
            $$ = []ast.Expr{$1}
        } | 
        varlist ',' var {
            $$ = append($1, $3)
        }

var:
        TK_NAME {
            $$ = &ast.IdentExpr{Value:$1.Str}
            $$.SetLine($1.Pos.Line)
        } |
        prefixexp '[' expr ']' {
            $$ = &ast.AttrGetExpr{Object: $1, Key: $3}
            $$.SetLine($1.Line())
        } | 
        prefixexp '.' TK_NAME {
            key := &ast.StringExpr{Value:$3.Str}
            key.SetLine($3.Pos.Line)
            $$ = &ast.AttrGetExpr{Object: $1, Key: key}
            $$.SetLine($1.Line())
        }

namelist:
        TK_NAME {
            $$ = []string{$1.Str}
        } | 
        namelist ','  TK_NAME {
            $$ = append($1, $3.Str)
        }

exprlist:
        expr {
            $$ = []ast.Expr{$1}
        } |
        exprlist ',' expr {
            $$ = append($1, $3)
        }

expr:
        TK_NIL {
            $$ = &ast.NilExpr{}
            $$.SetLine($1.Pos.Line)
        } | 
        TK_FALSE {
            $$ = &ast.FalseExpr{}
            $$.SetLine($1.Pos.Line)
        } | 
        TK_TRUE {
            $$ = &ast.TrueExpr{}
            $$.SetLine($1.Pos.Line)
        } | 
        TK_NUMBER {
            $$ = &ast.NumberExpr{Value: $1.Str}
            $$.SetLine($1.Pos.Line)
        } | 
        T3Comma {
            $$ = &ast.Comma3Expr{}
            $$.SetLine($1.Pos.Line)
        } |
        function {
            $$ = $1
        } | 
        prefixexp {
            $$ = $1
        } |
        string {
            $$ = $1
        } |
        tableconstructor {
            $$ = $1
        } |
        expr TK_OR expr {
            $$ = &ast.LogicalOpExpr{Lhs: $1, Operator: "or", Rhs: $3}
            $$.SetLine($1.Line())
        } |
        expr TK_AND expr {
            $$ = &ast.LogicalOpExpr{Lhs: $1, Operator: "and", Rhs: $3}
            $$.SetLine($1.Line())
        } |
        expr '>' expr {
            $$ = &ast.RelationalOpExpr{Lhs: $1, Operator: ">", Rhs: $3}
            $$.SetLine($1.Line())
        } |
        expr '<' expr {
            $$ = &ast.RelationalOpExpr{Lhs: $1, Operator: "<", Rhs: $3}
            $$.SetLine($1.Line())
        } |
        expr TK_GE expr {
            $$ = &ast.RelationalOpExpr{Lhs: $1, Operator: ">=", Rhs: $3}
            $$.SetLine($1.Line())
        } |
        expr TK_LE expr {
            $$ = &ast.RelationalOpExpr{Lhs: $1, Operator: "<=", Rhs: $3}
            $$.SetLine($1.Line())
        } |
        expr TK_EQ expr {
            $$ = &ast.RelationalOpExpr{Lhs: $1, Operator: "==", Rhs: $3}
            $$.SetLine($1.Line())
        } |
        expr TK_NE expr {
            $$ = &ast.RelationalOpExpr{Lhs: $1, Operator: "~=", Rhs: $3}
            $$.SetLine($1.Line())
        } |
        expr T2Comma expr {
            $$ = &ast.StringConcatOpExpr{Lhs: $1, Rhs: $3}
            $$.SetLine($1.Line())
        } |
        expr '+' expr {
            $$ = &ast.ArithmeticOpExpr{Lhs: $1, Operator: "+", Rhs: $3}
            $$.SetLine($1.Line())
        } |
        expr '-' expr {
            $$ = &ast.ArithmeticOpExpr{Lhs: $1, Operator: "-", Rhs: $3}
            $$.SetLine($1.Line())
        } |
        expr '*' expr {
            $$ = &ast.ArithmeticOpExpr{Lhs: $1, Operator: "*", Rhs: $3}
            $$.SetLine($1.Line())
        } |
        expr '/' expr {
            $$ = &ast.ArithmeticOpExpr{Lhs: $1, Operator: "/", Rhs: $3}
            $$.SetLine($1.Line())
        } |
        expr '%' expr {
            $$ = &ast.ArithmeticOpExpr{Lhs: $1, Operator: "%", Rhs: $3}
            $$.SetLine($1.Line())
        } |
        expr '^' expr {
            $$ = &ast.ArithmeticOpExpr{Lhs: $1, Operator: "^", Rhs: $3}
            $$.SetLine($1.Line())
        } |
        '-' expr %prec UNARY {
            $$ = &ast.UnaryMinusOpExpr{Expr: $2}
            $$.SetLine($2.Line())
        } |
        TK_NOT expr %prec UNARY {
            $$ = &ast.UnaryNotOpExpr{Expr: $2}
            $$.SetLine($2.Line())
        } |
        '#' expr %prec UNARY {
            $$ = &ast.UnaryLenOpExpr{Expr: $2}
            $$.SetLine($2.Line())
        } | 
        TK_SHORTCOMMENT {
            $$ = &ast.CommentExpr{Value: $1.Str}
        }

string: 
        TK_STRING {
            $$ = &ast.StringExpr{Value: $1.Str}
            $$.SetLine($1.Pos.Line)
        } 

prefixexp:
        var {
            $$ = $1
        } |
        afunctioncall {
            $$ = $1
        } |
        functioncall {
            $$ = $1
        } |
        '(' expr ')' {
            $$ = $2
            $$.SetLine($1.Pos.Line)
        }

afunctioncall:
        '(' functioncall ')' {
            $2.(*ast.FuncCallExpr).AdjustRet = true
            $$ = $2
        }

functioncall:
        prefixexp args {
            $$ = &ast.FuncCallExpr{Func: $1, Args: $2}
            $$.SetLine($1.Line())
        } |
        prefixexp ':' TK_NAME args {
            $$ = &ast.FuncCallExpr{Method: $3.Str, Receiver: $1, Args: $4}
            $$.SetLine($1.Line())
        }

args:
        '(' ')' {
            if yylex.(*Lexer).PNewLine {
               yylex.(*Lexer).TokenError($1, "ambiguous syntax (function call x new statement)")
            }
            $$ = []ast.Expr{}
        } |
        '(' exprlist ')' {
            if yylex.(*Lexer).PNewLine {
               yylex.(*Lexer).TokenError($1, "ambiguous syntax (function call x new statement)")
            }
            $$ = $2
        } |
        tableconstructor {
            $$ = []ast.Expr{$1}
        } | 
        string {
            $$ = []ast.Expr{$1}
        }

function:
        TK_FUNCTION funcbody {
            $$ = &ast.FunctionExpr{ParList:$2.ParList, Stmts: $2.Stmts}
            $$.SetLine($1.Pos.Line)
            $$.SetLastLine($2.LastLine())
        }

funcbody:
        '(' parlist ')' block TK_END {
            $$ = &ast.FunctionExpr{ParList: $2, Stmts: $4}
            $$.SetLine($1.Pos.Line)
            $$.SetLastLine($5.Pos.Line)
        } | 
        '(' ')' block TK_END {
            $$ = &ast.FunctionExpr{ParList: &ast.ParList{HasVargs: false, Names: []string{}}, Stmts: $3}
            $$.SetLine($1.Pos.Line)
            $$.SetLastLine($4.Pos.Line)
        }

parlist:
        T3Comma {
            $$ = &ast.ParList{HasVargs: true, Names: []string{}}
        } | 
        namelist {
          $$ = &ast.ParList{HasVargs: false, Names: []string{}}
          $$.Names = append($$.Names, $1...)
        } | 
        namelist ',' T3Comma {
          $$ = &ast.ParList{HasVargs: true, Names: []string{}}
          $$.Names = append($$.Names, $1...)
        }


tableconstructor:
        '{' '}' {
            $$ = &ast.TableExpr{Fields: []*ast.Field{}}
            $$.SetLine($1.Pos.Line)
        } |
        '{' fieldlist '}' {
            $$ = &ast.TableExpr{Fields: $2}
            $$.SetLine($1.Pos.Line)
        }


fieldlist:
        field {
            $$ = []*ast.Field{$1}
        } | 
        fieldlist fieldsep field {
            $$ = append($1, $3)
        } | 
        fieldlist fieldsep {
            $$ = $1
        }

field:
        TK_NAME '=' expr {
            $$ = &ast.Field{Key: &ast.StringExpr{Value:$1.Str}, Value: $3}
            $$.Key.SetLine($1.Pos.Line)
        } | 
        '[' expr ']' '=' expr {
            $$ = &ast.Field{Key: $2, Value: $5}
        } |
        expr {
            $$ = &ast.Field{Value: $1}
        }

fieldsep:
        ',' {
            $$ = ","
        } | 
        ';' {
            $$ = ";"
        }

%%

func TokenName(c int) string {
    start := TK_AND-3
	if c >= start && c-start < len(yyToknames) {
		if yyToknames[c-start] != "" {
			return yyToknames[c-start]
		}
	}
    return "CHAR " + string([]byte{byte(c)})
}

