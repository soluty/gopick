#!/usr/bin/env bash
# set -xeuo pipefail

main() {
	# rg, gopls, sed, goimports, gopickimports
	checkCommands
	local filename=""
	local funcname=""
	local start=0
	local end=0

	# parseArgs
	while getopts ":f:m:s:e:" opt; do
		case $opt in
		f)
			filename=$OPTARG
			;;
		m)
			funcname=$OPTARG
			;;
		s)
			start=$OPTARG
			;;
		e)
			end=$OPTARG
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			exit 1
			;;
		:)
			echo "Option -$OPTARG requires an argument." >&2
			exit 1
			;;
		esac
	done
	# checkParams
	if [ -z "$filename" ] || [ ! -f "$filename" ]; then
		echo "Invalid or missing file name: $filename" >&2
		exit 1
	fi
	filename=$(readlink -f "$filename")
	local dirname=$(dirname "$filename")
  # !important! in go project can use gopls.
  cd $dirname

	local funcSign=$(timeout 5s gopls symbols $filename | grep "$funcname Function")
	if [ -z "$funcname" ] || [ -z "$funcSign" ]; then
		echo "Invalid or function name: $funcname. are you in a " >&2
		exit 1
	fi
	if ! [[ "$start" =~ ^[0-9]+$ ]]; then
		echo "Invalid or missing start number: $start" >&2
		exit 1
	fi

	if ! [[ "$end" =~ ^[0-9]+$ ]]; then
		echo "Invalid or missing end number: $end" >&2
		exit 1
	fi
	local funcPos=$(echo "$funcSign" | awk -F " " '{print $3}')
	funcPos=$(echo "$funcPos" | cut -d '-' -f1)
	local fstart=$(echo "$funcPos" | cut -d ':' -f1)
	local fend=$(rg --line-number ^} "$filename" | awk -F ":" -v var="$fstart" '$1 > var {print $1; exit}')
	if [ "$start" -gt "$end" ]; then
		local temp=$start
		start=$end
		end=$temp
	fi
	if [ "$start" -eq 0 ]; then
		start=$((fstart))
	fi
	if [ "$end" -eq 0 ]; then
		end=$((fend))
	fi
	if [ "$end" -ge "$fend" ]; then
		end=$((fend))
	fi
	if [ "$start" -gt "$end" ]; then
		echo "Invalid start and end number: $start-$end" >&2
		exit 1
	fi
	# echo "File: $filename"
	# echo "Function: $funcSign"
	# echo "Start: $start"
	# echo "End: $end"
	# echo "fStart: $fstart"
	# echo "fEnd: $fend"
	# echo "pos: $funcPos"

	echo "package main"


	for file in "$dirname"/*.go; do
		if [[ -f "$file" ]]; then
			printAllImport "$file"
		fi
	done

	for file in "$dirname"/*.go; do
		if [[ -f "$file" ]]; then
			printAllTypes "$file"
		fi
	done

	first=""
	while read -r line1 && read -r line2; do
		filename=$(extractFromString "$line1" 1)
		funcname=$(extractFromString "$line1" 2)
		startpos=$(extractFromString "$line1" 3)
		startline=$(extractFromString "$startpos" 1 ":")
		endline=$(echo "$line2")
		# echo "line=$line1 $line2 sl=$startline,el=$endline,st=$start,ed=$end"
		if [ -z $first ]; then
			if [ "$funcname" != "main" ]; then
				echo "func main() {"
				echo "$funcname()"
				echo "}"
			fi
			if [ "$startline" -lt "$start" ]; then
				sed -n -e "$startline p" $filename
			fi
		fi
		if [ -z $first ]; then
			sed -n -e "$start,$end p" $filename
		else
			sed -n -e "$startline,$endline p" $filename
		fi
		if [ -z $first ]; then
			first="a"
			if [ "$startline" -lt "$start" ]; then
				sed -n -e "$endline p" $filename
			fi
		fi
	done <<<$(startParseNeededFunctions "$filename" "$funcname" "$funcPos")
	# extractFromString "callee[0]: ranges 6:2-5 in /root/proj/test/test/main.go from/to function sub in /root/proj/test/sub.go:3:6-10" " " 2
	# extractFromString "/root/proj/test/sub.go:3:6-10" ":" 1
}

checkCommands() {
	if ! command -v rg &>/dev/null; then
		echo "need command rg"
		exit 1
	fi
	if ! command -v sed &>/dev/null; then
		echo "need command sed"
		exit 1
	fi
	if ! command -v gopls &>/dev/null; then
		echo "need command gopls"
		exit 1
	fi
	# if ! command -v goimports &>/dev/null; then
	# 	echo "need command goimports"
	# 	exit 1
	# fi
	if ! command -v gopickimports &>/dev/null; then
		echo "need command gopickimports"
		exit 1
	fi
}

printAllImport() {
	local filename=$1
	# filename="test/main.go"
	# this way cannot process dot import and aliase import
	# echo "import ("
	# go list -f '{{join .Imports "\n"}}'
	# echo ")"
	gopickimports $filename
}

extractFromString() {
	local str=$1
	local position=$2
	local delimiter=$3
	if [ -z "$delimiter" ]; then
		delimiter=" "
	fi
	local result=$(echo "$str" | awk -v pos="$position" -F "$delimiter" '{print $pos}')
	echo "$result"
}

getConstEndLine() {
	# filename="$(pwd)/test/main.go"
	# fstart=8
	# startCol=2
	local filename="$1"
	local fstart="$2"
	local startCol="$3"
	if [ "$startCol" = 2 ]; then
		local fend=$(rg --line-number "^\)" "$filename" | awk -F ":" -v var="$fstart" '$1 > var {print $1; exit}')
		echo $fend
	else
		echo $fstart
	fi
}

getTypeEndLine() {
	# filename="$(pwd)/test/main.go"
	# fstart=44
	# startCol=5
	local filename="$1"
	local fstart="$2"
	local startCol="$3"
	if [ "$startCol" = 2 ]; then
		local fend=$(rg --line-number "^\)" "$filename" | awk -F ":" -v var="$fstart" '$1 > var {print $1; exit}')
		echo $fend
		return
	fi
	local startLine=$(sed -n -e "$fstart p" "$filename")
	local last_char=${startLine: -1}
	if [ "$last_char" = "}" ]; then
		echo $fstart
		return
	fi
	local fend=$(rg --line-number "^}" "$filename" | awk -F ":" -v var="$fstart" '$1 > var {print $1; exit}')
	echo $fend
}

printAllTypes() {
	# filename="$(pwd)/test/main.go"
	local filename=$1
	local first=""
	while read -r line; do
		# echo $line
		local pos=$(extractFromString "$line" 3)
		local typ=$(extractFromString "$line" 2)
		local tmp=$(extractFromString "$pos" 1 "-")
		local start=$(extractFromString "$tmp" 1 ":")
		local col=$(extractFromString "$tmp" 2 ":")
		if [ -z "$first" ]; then
			local end=0
			if [ $typ = "Constant" ]; then
				end=$(getConstEndLine "$filename" $start $col)
			elif [ $typ = "Struct" ]; then
				end=$(getTypeEndLine "$filename" $start $col)
			elif [ $typ = "Class" ]; then
				end=$(getConstEndLine "$filename" $start $col)
			fi
			# echo "start=$start,end=$end"
			if [ "$start" = "$end" ]; then
				sed -n -e "$start p" "$filename"
				first=""
				continue
			fi
			if [ $typ = "Constant" ]; then
				echo "const ("
			elif [ $typ = "Struct" ]; then
				if [ $col = 2 ]; then
					echo "type ("
				fi
			elif [ $typ = "Class" ]; then
				if [ $col = 2 ]; then
					echo "type ("
				fi
			fi
			sed -n -e "$start,$end p" "$filename"
			first=$end
		else
			if [ $start -ge $first ]; then
				first=""
				local end=0
				if [ $typ = "Constant" ]; then
					end=$(getConstEndLine "$filename" $start $col)
				elif [ $typ = "Struct" ]; then
					end=$(getTypeEndLine "$filename" $start $col)
				elif [ $typ = "Class" ]; then
					end=$(getConstEndLine "$filename" $start $col)
				fi
				# echo "start=$start,end=$end"
				if [ "$start" = "$end" ]; then
					sed -n -e "$start p" "$filename"
					first=""
					continue
				fi
				if [ $typ = "Constant" ]; then
					echo "const ("
				elif [ $typ = "Struct" ]; then
					if [ $col = 2 ]; then
						echo "type ("
					fi
				elif [ $typ = "Class" ]; then
					if [ $col = 2 ]; then
						echo "type ("
					fi
				fi
				sed -n -e "$start,$end p" "$filename"
				first=$end
			fi
		fi
	done <<<$(gopls symbols "$filename" | rg "Constant|Struct|Class")
}

getFuncEndLine() {
	local filename="$1"
	local fstart="$2"
	local startLine=$(sed -n -e "$fstart p" $filename)
	local last_char=${startLine: -1}
	if [ "$last_char" = "}" ]; then
		echo $fstart
		return
	fi
	local fend=$(rg --line-number ^} "$filename" | awk -F ":" -v var="$fstart" '$1 > var {print $1; exit}')
	echo $fend
}

startParseNeededFunctions() {
	#  local filename="$(pwd)/test/main.go"
	# local funcname="nest"
	# local funcPos="67:6"
	local filename=$1
	local funcname=$2
	local funcPos=$3
	echo "$filename $funcname $funcPos"
	parseNeededFunctions $filename $funcname $funcPos
}

parseNeededFunctions() {
	local filename="$1"
	local dirname=$(dirname "$filename")
	local funcname="$2"
	local funcPos="$3"
	local start=$(echo "$funcPos" | cut -d ':' -f1)
	local end=$(getFuncEndLine "$filename" "$start")
	# echo "funcPos=$funcPos"
	# echo "fstart=$fstart"
	# echo "fend=$fend"
	# local start="$4"
	# local end="$5"
	# if [ "$start" -eq 0 ]; then
	# 	start=$((fstart))
	# fi
	# if [ "$end" -eq 0 ]; then
	# 	end=$((fend))
	# fi
	local output=$(gopls call_hierarchy "$filename:$funcPos")
	# echo output=$output
	local idline=$(echo "$output" | grep -n "identifier: function $funcname" | cut -d: -f1)
	# echo idline=$idline
	local callees=$(echo "$output" | awk -v start=$((idline + 1)) 'NR >= start {print}')
	echo $end
	if [[ -z "$callees" ]]; then
		return
	fi
	while IFS= read -r line; do
		local parsedArr=$(parseCallLine "$line")
		IFS=' ' read -r newfilename newfuncname newfuncpos <<<"$parsedArr"
		# echo a=$newfilename
		# echo b=$newfuncname
		# echo c=$newfuncpos
		local newdirname=$(dirname "$newfilename")
		if [ "$newdirname" = "$dirname" ]; then
			# echo "same dir $dirname"
			echo "$parsedArr"
			parseNeededFunctions "$newfilename" "$newfuncname" "$newfuncpos" 0 0
			# continue
		fi
	done <<<"$callees"
}

parseCallLine() {
	local line="$1"
  # line="callee[0]: ranges 6:2-5 in $(pwd)/test/main.go from/to function sub in $(pwd)/test/sub.go:3:6-10"
	funcStr=$(extractFromString "$line" 10)
	funcName=$(extractFromString "$line" 8)
	fileName=$(extractFromString "$funcStr" 1 ":")
	funcPos=$(extractFromString "$funcStr" 2 ":")
	funcCols=$(extractFromString "$funcStr" 3 ":")
	funcCol=$(extractFromString "$funcCols" 1 "-")
	echo "$fileName $funcName $funcPos:$funcCol"
	# echo "$fileName"
	# echo "$funcName"
	# echo "$funcPos:$funcCol"
}

main "$@"
