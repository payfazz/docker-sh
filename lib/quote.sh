#!/bin/sh

quote() (
  ret=; curr=; PSret=; tmp=; token=; no_proc=${no_proc:-n}; count=${count:--1};
  if [ "$count" != "$((count+0))" ]; then echo "count must be integer" >&2; return 1; fi
  case $no_proc in y|n) : ;; *) echo "no_proc must be y or n" >&2; return 1 ;; esac
  SEP=$(printf "\n \t"); nl=$(printf '\nx'); nl=${nl%x};
  for rest; do
    nextop=RN
    while [ "$count" != 0 ]; do
      case $nextop in
      R*) nextop="P${nextop#?}"
          token=${rest%%[!$SEP]*}; rest=${rest#"$token"}
          if [ -z "$token" ]; then token=${rest%%[$SEP]*}; rest=${rest#"$token"}; fi
          if [ -z "$token" ] && [ -z "$rest" ] && [ -z "$curr" ]; then break; fi ;;
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
