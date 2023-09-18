package main

import (
	"fmt"
	af "fmt"
	bf "fmt"
)
type b int
var str = "geta/aaa"

type as struct {
	a int
}

const (
	mm  = 1
	mm1 = 1
)
const mmm = 1
const (
	uu = iota
	uu2
	uu3
)

type (
	asdf = struct{}
)

type asdf2 = struct{}

var ass = 1

var vv = vvv()

func vvv() int {
	return 1
}

type amm int

type (
	aa struct {
		a int
		b struct {
			c int
		}
	}
	bb string
)

var mv = 1

func main() {
  af.Println(122)
  bf.Println(122)
	sub()
	print(123)
	var v a
	v.main()
	m(2)
	nest()
}

func (b a) main() {
	fmt.Println(123)
}

func m[T any](t T) {
	print(t)
}

func nest() {
	nest2()
}

func nest2() {
	print(12)
	nest3()
}

func nest3() { /*
	 */
}
