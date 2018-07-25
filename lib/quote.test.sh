#!/bin/dash
set -eu
cd "$(dirname "$0")"

. ./quote.sh

dotest() {
  testid=$1A
  retcode=$2
  input=$3
  output=$4
  set +e
  real_output=$(quote "$input" 2>/dev/null)
  real_retcode=$?
  set -e
  if [ "$output" = "$real_output" -a "$retcode" = "$real_retcode" ]; then
    echo "TEST $testid OK"
  else
    printf "TEST %s\nRESULT(%s): %s\nNEED(%s)  : %s\n" \
      "$testid" "$real_retcode" "$real_output" "$retcode" "$output"
    exit 1
  fi

  testid=$1B
  retcode=0
  input=$3
  output=$5
  set +e
  real_output=$(no_proc=y quote "$input" 2>/dev/null)
  real_retcode=$?
  set -e
  if [ "$output" = "$real_output" -a "$retcode" = "$real_retcode" ]; then
    echo "TEST $testid OK"
  else
    printf "TEST %s\nRESULT(%s): %s\nNEED(%s)  : %s\n" \
      "$testid" "$real_retcode" "$real_output" "$retcode" "$output"
    exit 1
  fi
}

dotest 1 0 "" "" ""

dotest 2 0 "asdgaweg\\ " "'asdgaweg '" "'asdgaweg\'"

dotest 3 0 "a \ cde f" "'a' ' cde' 'f'" "'a' '\' 'cde' 'f'"

dotest 4 0 "asdgaweg\\  " "'asdgaweg '" "'asdgaweg\'"

dotest 5 1 "asdgaweg\\" "" "'asdgaweg\'"

dotest 6 0 "

a b
te\\'st\\ \\     g\\
e c\bed d
" "'a' 'b' 'te'\''st  ' 'ge' 'cbed' 'd'" "'a' 'b' 'te\'\''st\' '\' 'g\' 'e' 'c\bed' 'd'"

dotest 7 0 "a'ae'a'eg'e  a'a e'a a'a e' 'a e'a 'a e' a'a\\e'a a'a\\e' 'a\\e'a 'a\\e' g\\
e c\bed d" \
"'aaeaege' 'aa ea' 'aa e' 'a ea' 'a e' 'aa\ea' 'aa\e' 'a\ea' 'a\e' 'ge' 'cbed' 'd'" \
"'a'\''ae'\''a'\''eg'\''e' 'a'\''a' 'e'\''a' 'a'\''a' 'e'\''' ''\''a' 'e'\''a' ''\''a' 'e'\''' 'a'\''a\e'\''a' 'a'\''a\e'\''' ''\''a\e'\''a' ''\''a\e'\''' 'g\' 'e' 'c\bed' 'd'"

dotest 8 0 "

a b
te\\'st\\ \\  a'ae'a'eg'e  a'ae'a a'ae' 'ae'a 'ae' a'a\\e'a a'a\\e' 'a\\e'a 'a\\e' g\\
e c\bed d
" \
"'a' 'b' 'te'\''st  ' 'aaeaege' 'aaea' 'aae' 'aea' 'ae' 'aa\ea' 'aa\e' 'a\ea' 'a\e' 'ge' 'cbed' 'd'" \
"'a' 'b' 'te\'\''st\' '\' 'a'\''ae'\''a'\''eg'\''e' 'a'\''ae'\''a' 'a'\''ae'\''' ''\''ae'\''a' ''\''ae'\''' 'a'\''a\e'\''a' 'a'\''a\e'\''' ''\''a\e'\''a' ''\''a\e'\''' 'g\' 'e' 'c\bed' 'd'"

dotest 9 0 "adf'geag'eae'ee awew' ha'i''' '\"asdf\"'  asgew'           'ee" \
"'adfgeageaeee awew' 'hai' '\"asdf\"' 'asgew           ee'" \
"'adf'\''geag'\''eae'\''ee' 'awew'\''' 'ha'\''i'\'''\'''\''' ''\''\"asdf\"'\''' 'asgew'\''' ''\''ee'"


dotest 10 1 "'" "" "''\'''"

dotest 11 0 "

a b
te\\'st\\ \\   a\"ae\"a a\"ae\" \"ae\"a \"ae\" a\"a\\e\"a a\"a\\e\" \"a\\e\"a \"a\\e\" g\\
e c\bed d
" \
"'a' 'b' 'te'\''st  ' 'aaea' 'aae' 'aea' 'ae' 'aa\ea' 'aa\e' 'a\ea' 'a\e' 'ge' 'cbed' 'd'" \
"'a' 'b' 'te\'\''st\' '\' 'a\"ae\"a' 'a\"ae\"' '\"ae\"a' '\"ae\"' 'a\"a\e\"a' 'a\"a\e\"' '\"a\e\"a' '\"a\e\"' 'g\' 'e' 'c\bed' 'd'"

dotest 12 0 "a\"a\\\\e\"a a\"a\\\\e\" \"a\\\\e\"a \"a\\\\e\"" \
"'aa\ea' 'aa\e' 'a\ea' 'a\e'" \
"'a\"a\\\\e\"a' 'a\"a\\\\e\"' '\"a\\\\e\"a' '\"a\\\\e\"'"

dotest 13 0 "

a b
te\\'st\\ \\   a\"ae\"a a\"ae\" \"ae\"a \"ae\" a\"a\\\\e\"a a\"a\\\\e\" \"a\\\\e\"a \"a\\\\e\" g\\
e c\bed d
" \
"'a' 'b' 'te'\''st  ' 'aaea' 'aae' 'aea' 'ae' 'aa\ea' 'aa\e' 'a\ea' 'a\e' 'ge' 'cbed' 'd'" \
"'a' 'b' 'te\'\''st\' '\' 'a\"ae\"a' 'a\"ae\"' '\"ae\"a' '\"ae\"' 'a\"a\\\\e\"a' 'a\"a\\\\e\"' '\"a\\\\e\"a' '\"a\\\\e\"' 'g\' 'e' 'c\bed' 'd'"

dotest 14 0 "a \"age'haeee'eee\" bebe" \
"'a' 'age'\''haeee'\''eee' 'bebe'" \
"'a' '\"age'\''haeee'\''eee\"' 'bebe'"

dotest 15 0 "a \"age'ha\
eee'eee\" bebe" \
"'a' 'age'\''haeee'\''eee' 'bebe'" \
"'a' '\"age'\''haeee'\''eee\"' 'bebe'"

dotest 16 1 '"' "" "'\"'"

dotest 17 0 "
  -v '/ / / / / /data:/var/lib/mysql'
  --network-alias db

  -e MYSQL_ROOT_PASSWORD=root
" \
"'-v' '/ / / / / /data:/var/lib/mysql' '--network-alias' 'db' '-e' 'MYSQL_ROOT_PASSWORD=root'" \
"'-v' ''\''/' '/' '/' '/' '/' '/data:/var/lib/mysql'\''' '--network-alias' 'db' '-e' 'MYSQL_ROOT_PASSWORD=root'"

dotest 18 0 "
  -p 8080:80

  -e PMA_HOST=db
" \
"'-p' '8080:80' '-e' 'PMA_HOST=db'" \
"'-p' '8080:80' '-e' 'PMA_HOST=db'"

dotest 19 0 "\"asdf\\\"aweg\"" \
"'asdf\"aweg'" \
"'\"asdf\\\"aweg\"'"
