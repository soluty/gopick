package main

import (
	"fmt"
	"go/parser"
	"go/token"
	"os"
)

func main() {
	if len(os.Args) < 2 {
		println("useage: gopickimports file.go")
		os.Exit(1)
	}
	filePath := os.Args[1]
	bs, err := os.ReadFile(filePath)
	if err != nil {
		println(fmt.Sprintf("read file %s error: %v", filePath, err))
		os.Exit(1)
	}
	fset := token.NewFileSet()
	file, err := parser.ParseFile(fset, "", bs, parser.ParseComments)
	if err != nil {
		fmt.Println("pasre error:", err)
		os.Exit(1)
	}
	if len(file.Imports) == 0 {
		return
	}
	fmt.Println("import (")
	for _, imp := range file.Imports {
		importPath := imp.Path.Value
		if imp.Name != nil {
			alias := imp.Name.Name
			fmt.Printf("%s %s\n", alias, importPath)
		} else {
			fmt.Printf("%s\n", importPath)
		}
	}
	fmt.Println(")")
}
