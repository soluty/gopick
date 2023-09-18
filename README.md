This project contains a tool to pickup a piece of code from a formatted go project.

It is designed to used in [code_runner](https://github.com/michaelb/sniprun) to run 
some selected code or run a function in a go project.

It can run code almost like the code in real project run. Except it ignored init
function in package, and it ignored global variables, the two are useally not think as
good design.

# Platform
linux, maybe macos, but not tested.

# Dependency
rg sed awk gopls, this tools are very common tools in linux platform

# Limitation
1. now it is not suppose project path contains space.
2. the generate code maybe not a valid main.go, it may contains some unused import and 
same import. It need the [code_runner](https://github.com/michaelb/sniprun) to run
goimports main.go to fix it then it will be valid.

# Install
1. clone project
2. `cd gopickimports && go build . && mv gopickimports /usr/bin/`
3. then you can run pickup.sh as common shell script or shebang now

# Use
`pickup.sh -f $filename -m $methoedname [-s startline] [-e endline]`
then see the output.
