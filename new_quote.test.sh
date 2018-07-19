#!/bin/dash

set -eu

DEBUG=off

quote_old() (
  ret=; nl=$(printf '\nx'); nl=${nl%x}; no_proc=${no_proc:-n}; count=${count:--1}
  for next; do
    char=; current=; state=discard; read=y; backslash_ret=
    while [ "$count" != 0 ]; do
      case $read in
      n)  read=y ;;
      y)  case $next in "") case $state in
            discard)        break ;;
            normal)         ret="$ret'$current' "; count=$((count-1))
                            break ;;
            backslash)      echo 'premature end of string' >&2; return 1 ;;
            single|double)  echo "unmatched $state quote" >&2; return 1 ;;
          esac ;; esac
          char=${next%"${next#?}"}; next=${next#"$char"} ;;
      esac
      case $state in
      discard)    case $char in [!$IFS]) state=normal; read=n ;; esac ;;
      normal)     case $no_proc in
                  n)  case $char in
                      \\)     backslash_ret=$state; state=backslash ;;
                      \')     state=single; ;;
                      \")     state=double; ;;
                      [$IFS]) ret="$ret'$current' "; count=$((count-1))
                              current=; state=discard ;;
                      *)      current="$current$char" ;;
                      esac ;;
                  y)  case $char in
                      \')     current="$current'\\''" ;;
                      [$IFS]) ret="$ret'$current' "; count=$((count-1))
                              current=; state=discard ;;
                      *)      current="$current$char" ;;
                      esac ;;
                  esac ;;
      backslash)  state=$backslash_ret
                  case $char in
                  $nl) : ;;
                  \\) current="$current$char" ;;
                  \") current="$current$char" ;;
                  \') case $backslash_ret in
                      normal) current="$current'\\''" ;;
                      *)      current="$current\\'\\''" ;;
                      esac ;;
                  *)  case $backslash_ret in
                      normal) current="$current$char" ;;
                      *)      current="$current\\$char" ;;
                      esac ;;
                  esac ;;
      single)     case $char in
                  \') state=normal ;;
                  *)  current="$current$char" ;;
                  esac ;;
      double)     case $char in
                  \\) backslash_ret=$state; state=backslash ;;
                  \') current="$current'\\''" ;;
                  \") state=normal ;;
                  *)  current="$current$char" ;;
                  esac ;;
      esac
    done
  done
  printf '%s\n' "${ret% }"
)

quote() (
  ret=; curr=; PSret=; tmp=; token=; no_proc=${no_proc:-n}; count=${count:--1};
  if ! ( count=$((count+0)) ) 2>/dev/null; then echo "count must be integer" >&2; return 1; fi
  case $no_proc in y|n) : ;; *) echo "no_proc must be y or n" >&2; return 1 ;; esac
  SEP=$(printf "\n \t"); nl=$(printf '\nx'); nl=${nl%x};
  for rest; do
    nextop=RN
    while [ "$count" != 0 ]; do
      if [ "$DEBUG" = "on" ]; then
        read -p "Press enter to continue" aaaaaaaaaaaaaaaaa
        printf "\n\nDEBUG nextop=%s ret=>%s< curr=>%s< token=>%s< rest=>%s<\n" "$nextop" "$ret" "$curr" "$token" "$rest" >&2
      fi
      case $nextop in
      R*) nextop="P${nextop#?}"
          token=${rest%%[!$SEP]*}; rest=${rest#"$token"}
          if [ -z "$token" ]; then token=${rest%%[$SEP]*}; rest=${rest#"$token"}; fi
          [ -z "$token" -a -z "$rest" -a -z "$curr" ] && break ;;
      PN) case $token in
          *[$SEP]*|'')
              nextop=RN; tmp=
              if [ -z "$token" ]; then [ -z "$rest" ] && tmp=y;
              else [ -n "$curr" ] && tmp=y; fi
              if [ "$tmp" ]; then ret="$ret'$curr' "; curr=; count=$((count-1)); fi ;;
          *)  case $no_proc in
              y)  ret="$ret$(printf %s\\n "$token" | sed "s/'/'\\\\''/g;1s/^/'/;\$s/\$/'/") "
                  count=$((count-1)); nextop=RN ;;
              n)  case $token in
                  *[\\\'\"]*)
                      tmp=${token%%[\\\'\"]*}; token=${token#"$tmp"}; curr="$curr$tmp"
                      case $token in
                      \\*) token=${token#\\}; nextop=PS; PSret=PN ;;
                      \'*) token=${token#\'}; nextop=PQ ;;
                      \"*) token=${token#\"}; nextop=PD ;;
                      esac ;;
                  *)  ret="$ret'$curr$token' "; curr=; count=$((count-1)); nextop=RN ;;
                  esac ;;
              esac ;;
          esac ;;
      PS) tmp=${token%"${token#?}"}; token=${token#"$tmp"}
          case $tmp in
          '') nextop=RS
              if [ -z "$rest" ]; then echo 'premature end of string' >&2; return 1; fi ;;
          $nl) nextop=$PSret ;;
          \\) nextop=$PSret; curr="$curr$tmp" ;;
          \") nextop=$PSret; curr="$curr$tmp" ;;
          \') nextop=$PSret
              if [ "$PSret" = PN ]; then curr="$curr'\\''"
              else curr="$curr\\'\\''"; fi ;;
          *)  nextop=$PSret;
              if [ "$PSret" = PN ]; then curr="$curr$tmp"
              else curr="$curr\\$tmp"; fi ;;
          esac ;;
      PQ) tmp=${token%%\'*}; token=${token#"$tmp"}; curr="$curr$tmp"
          case $token in
          \'*)  token=${token#\'}; nextop=PN ;;
          '')   nextop=RQ
                if [ -z "$rest" ]; then echo 'unmatched single quote' >&2; return 1; fi ;;
          *)    curr="$curr$token"; token= ;;
          esac ;;
      PD) tmp=${token%%[\\\'\"]*}; token=${token#"$tmp"}; curr="$curr$tmp"
          case $token in
          \"*)  token=${token#\"}; nextop=PN ;;
          '')   nextop=RD
                if [ -z "$rest" ]; then echo 'unmatched double quote' >&2; return 1; fi ;;
          *[\\\']*)
                tmp=${token%%[\\\']*}; token=${token#"$tmp"}; curr="$curr$tmp"
                case $token in
                \\*) token=${token#\\}; nextop=PS; PSret=PD ;;
                \'*) token=${token#\'}; curr="$curr'\\''" ;;
                esac ;;
          *)    curr="$curr$token"; token= ;;
          esac ;;
      *)  printf "BUG: quote: invalid nextop >%s<\n" "$nextop" >&2; return 1 ;;
      esac
    done
  done
  printf %s\\n "${ret% }"
)

dotest() {
  a1=$(printf %s "$(quote "$data")")
  b1=$(printf %s "$(quote_old "$data")")
  if [ "$a1" = "$b1" ]; then
    echo "$1 OK"
  else
    printf "%s\nRESULT: %s\nNEED  : %s\n" "$1" "$a1" "$b1"
    exit 1
  fi
  a1=$(printf %s "$(no_proc=y quote "$data")")
  b1=$(printf %s "$(no_proc=y quote_old "$data")")
  if [ "$a1" = "$b1" ]; then
    echo "$1 OK"
  else
    printf "%s\nRESULT: %s\nNEED  : %s\n" "$1" "$a1" "$b1"
    exit 1
  fi
}

data=""
dotest 1

data="asdgaweg\\ "
dotest 2

data="a \ cde f"
dotest 3

data="asdgaweg\\  "
dotest 4

data="asdgaweg\\"
dotest 5

data="

a b
te\\'st\\ \\     g\\
e c\bed d
"
dotest 6

data="a'ae'a'eg'e  a'a e'a a'a e' 'a e'a 'a e' a'a\\e'a a'a\\e' 'a\\e'a 'a\\e' g\\
e c\bed d"
dotest 7

data="

a b
te\\'st\\ \\  a'ae'a'eg'e  a'ae'a a'ae' 'ae'a 'ae' a'a\\e'a a'a\\e' 'a\\e'a 'a\\e' g\\
e c\bed d
"
dotest 8

data="adf'geag'eae'ee awew' ha'i''' '\"asdf\"'  asgew'           'ee"
dotest 9


data="'"
dotest 10

data="

a b
te\\'st\\ \\   a\"ae\"a a\"ae\" \"ae\"a \"ae\" a\"a\\e\"a a\"a\\e\" \"a\\e\"a \"a\\e\" g\\
e c\bed d
"
dotest 11

data="a\"a\\\\e\"a a\"a\\\\e\" \"a\\\\e\"a \"a\\\\e\""
dotest 12a

data="

a b
te\\'st\\ \\   a\"ae\"a a\"ae\" \"ae\"a \"ae\" a\"a\\\\e\"a a\"a\\\\e\" \"a\\\\e\"a \"a\\\\e\" g\\
e c\bed d
"
dotest 12

data="a \"age'haeee'eee\" bebe"
dotest 13

data="a \"age'ha\
eee'eee\" bebe"
dotest 14

data='"'
dotest 15

data="
  -v '/ / / / / /data:/var/lib/mysql'
  --network-alias db

  -e MYSQL_ROOT_PASSWORD=root
"
dotest 16

data="
  -p 8080:80

  -e PMA_HOST=db
"
dotest 17

data="\"asdf\\\"aweg\""
dotest 18
