
all:
	make lex
	make parse

lex:
	golex lua.lex

parse:
	goyacc -o parse.go lua.yy