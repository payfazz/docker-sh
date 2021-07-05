#!/bin/sh

# Author: win@payfazz.com
# source code is hosted on https://github.com/payfazz/docker-sh

# Note:
# every code must compatible with POSIX shell

set -eu

_help_str="Available commands:
  start              Start the container
  stop               Stop the container
  restart            Restart the container
  rm                 Remove the container
  exec               Exec program inside the container
  exec_root          Exec program inside the container (as root)
  exec_as            Exec program inside the container as specified user
  kill               Force kill the container
  logs               Show the log of the container
  port               Show port forwarding
  status             Show status of the container
  name               Show the name of the container
  image              Show the image of the container
  net                Show the primary network of the container
  show_cmds          Show the arguments to docker run
  show_running_cmds  Show the arguments to docker run in current running container
  pull               Pull the image
  ip                 Show the container ip
  pid                Show the PID of main process in container
  update             pull the image and recreate container
                     if status return different_image or different_opts
  inspect            Show the low-level of the container
  stats              Show the stats of the container
  top                Show the running process inside container
  id                 Show the id of the container
  help               Show this message

NOTE:
- Custom command are not listed
- See https://github.com/payfazz/docker-sh/blob/master/DOCS.md#available-command for more info.
"

# this quote function copied from
# https://raw.githubusercontent.com/payfazz/sh-script/29740f001c4ddcdde581a777f2af0e4855bb1651/lib/quote.sh
# DO NOT EDIT
quote() (
  ret=; curr=; PSret=; tmp=; token=; no_proc=${no_proc:-n}; count=${count:--1};
  if [ "$count" != "$((count+0))" ]; then echo "count must be integer" >&2; return 1; fi
  case $no_proc in y|n) : ;; *) echo "no_proc must be y or n" >&2; return 1 ;; esac
  SEP=$(printf '\n \t'); nl=$(printf '\nx'); nl=${nl%x};
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
              if [ "$tmp" ]; then ret="$ret'$curr' "; curr=; : $((count=count-1)); fi ;;
          *)  case $no_proc in
              y)  ret="$ret$(printf %s\\n "$token" | LC_ALL=C sed "s/'/'\\\\''/g;1s/^/'/;\$s/\$/'/") "
                  : $((count=count-1)); nextop=RN ;;
              n)  case $token in
                  *[\\\'\"]*)
                      tmp=${token%%[\\\'\"]*}; token=${token#"$tmp"}; curr="$curr$tmp"
                      case $token in
                      \\*) token=${token#\\}; nextop=PS; PSret=PN ;;
                      \'*) token=${token#\'}; nextop=PQ ;;
                      \"*) token=${token#\"}; nextop=PD ;;
                      esac ;;
                  *)  ret="$ret'$curr$token' "; curr=; : $((count=count-1)); nextop=RN ;;
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
      *)  printf 'BUG: quote: invalid nextop >%s<\n' "$nextop" >&2; return 1 ;;
      esac
    done
  done
  printf %s\\n "${ret% }"
)

calc_cksum() {
  printf %s "$1" | cksum | LC_ALL=C tr -d ' '
}

exists() {
  case $1 in
  network|volume) [ "$(docker "$1" inspect -f ok "$2" 2>/dev/null)" = ok ] ;;
  *)              [ "$(docker inspect --type "$1" -f ok "$2" 2>/dev/null)" = ok ] ;;
  esac
}

running() {
  [ "$(docker inspect --type container -f '{{.State.Running}}' "$1" 2>/dev/null)" = true ]
}

panic() {
  if [ $# -gt 0 ]; then echo "$@" >&2; fi
  exit 1
}

_construct_run_cmds() {
  [ -z "${image:-}" ] && { echo '"image" cannot be empty' >&2; return 1; }
  [ -z "${name:-}" ]  && { echo '"name" cannot be empty'  >&2; return 1; }
  ret="$(quote "${opts:-}") " || { echo 'cannot process "opts"' >&2; return 1; }
  eval "set -- $ret"
  for arg; do
    case $arg in
    --name|--net|--network) printf '"opts" cannot contain "%s"\n' "$arg" >&2; return 1 ;;
    esac
  done
  ret="$ret'--name' $(no_proc=y count=1 quote "$name") "
  [ -n "${net:-}" ] && ret="$ret'--network' $(no_proc=y count=1 quote "$net") "
  ret="$ret$(no_proc=y count=1 quote "$image") "
  ret="$ret$(quote "${args:-}")" || { echo 'cannot process "args"' >&2; return 1; }
  ret=${ret# }
  ret=${ret% }
  printf %s "$ret"
}

_exec_if_fn_exists() (
  if type "$1" 2>/dev/null | grep -q -F function; then
    "$@" || {
      tmp=$?
      printf '"%s" return %d\n' "$1" $tmp >&2
      return $tmp
    }
  fi
  return 0
)

_random() {
  LC_ALL=C tr -cd '[:alnum:]' < /dev/urandom 2>/dev/null | head -c 16
}

_assert_local_docker() {
  str=$(_random)
  tmp_file=$(_random)
  if [ -z "${dir:-}" ]; then
    tmp_file="/tmp/$tmp_file"
  else
    tmp_file="$dir/$tmp_file"
  fi
  ( printf %s "$str" > "$tmp_file"; ) 2>/dev/null || return 1
  str2=$(docker run \
    --rm --entrypoint cat \
    -v "$tmp_file:/tmp/test-file:ro" \
    alpine /tmp/test-file 2>/dev/null
  ) || :
  rm -f "$tmp_file"
  [ "$str" = "$str2" ]
}

_update() {
  if ! running "$name" && [ "${create_only:-}" != y ]; then
    echo "WARNING: Container is not running, running the container after update" >&2
  fi
  echo "Recreating container ..." >&2
  { ( _main stop; ) && ( _main rm; ) && ( _main start; ); } || return $?
  return 0
}

_is_managed() {
  [ -n "${file:-}" ] && \
  [ "$file" = "$(docker inspect -f '{{index .Config.Labels "kurnia_d_win.docker.initial_spec_file"}}' "$name" 2>/dev/null)" ]
}

_main() {
  action=help
  [ $# -gt 0 ] && action=$1 && shift || :
  case ${action:-} in
    name) echo "$name"; exit 0 ;;
    image) echo "$image"; exit 0 ;;
    net) echo "${net:-bridge}"; exit 0 ;;
    show_cmds)
      constructed_run_cmds=$(_construct_run_cmds) || exit $?
      echo "$constructed_run_cmds";
      exit 0
      ;;

    start)
      if ! running "$name"; then
        if ! exists container "$name"; then
          if [ "${must_local:-}" = "y" ]; then
            _assert_local_docker || panic "docker daemon is not running on local machine"
          fi
          if [ -z "${file:-}" ]; then file="/dev/null"; fi
          constructed_run_cmds=$(_construct_run_cmds) || exit $?
          _exec_if_fn_exists "pre_$action" run || exit $?
          if ! exists image "$image"; then
            ( _main pull; ) || exit $?
            exists image "$image" || panic "image $image doesn't exists"
          fi
          case "${net:-}" in
          ""|container:*|bridge|host|none) : ;;
          *)  if ! exists network "$net"; then
                docker network create --driver bridge \
                  --label kurnia_d_win.docker.autoremove=true \
                  --label "kurnia_d_win.docker.initial_spec_file=$file" \
                  "$net" >/dev/null \
                || exit $?
              fi
              ;;
          esac
          eval "set -- $constructed_run_cmds"
          docker create \
            --label "kurnia_d_win.docker.run_opts=$constructed_run_cmds" \
            --label "kurnia_d_win.docker.initial_spec_file=$file" \
            "$@" >/dev/null || exit $?
          _exec_if_fn_exists "pre_$action" created || exit $?
          [ "${create_only:-}" = "y" ] && exit 0
          docker start "$name" >/dev/null || exit $?
          _exec_if_fn_exists "post_$action" run || exit $?
          exit 0
        else
          _is_managed || panic "container \"$name\" is not managed"
          [ "${create_only:-}" = "y" ] && exit 0
          _exec_if_fn_exists "pre_$action" start || exit $?
          docker start "$name" >/dev/null || exit $?
          _exec_if_fn_exists "post_$action" start || exit $?
          exit 0
        fi
      else
        _is_managed || panic "container \"$name\" is not managed"
      fi
      exit 0
      ;;

    stop|restart)
      if running "$name"; then
        _is_managed || panic "container \"$name\" is not managed"
        eval "set -- $(no_proc=y quote "${stop_opts:-}" "$@")"
        tmp_opts=; i=1
        while [ $i -le $# ]; do
          a=$(eval echo "\${$i}")
          case $a in
          -t|--time)
            : $((i=i+1)); a=$(eval echo "\${$i:-}")
            tmp_opts="$tmp_opts'--time' $(no_proc=y count=1 quote "$a") "
            ;;
          esac
          : $((i=i+1))
        done
        _exec_if_fn_exists "pre_$action" || exit $?
        eval "set -- $tmp_opts"
        docker "$action" "$@" "$name" >/dev/null || exit $?
        _exec_if_fn_exists "post_$action" || exit $?
        exit 0
      elif [ "$action" = restart ]; then
        panic 'container is not running'
      fi
      exit 0
      ;;

    rm)
      if exists container "$name"; then
        _is_managed || panic "container \"$name\" is not managed"
        eval "set -- $(no_proc=y quote "${rm_opts:-}" "$@")"
        tmp_opts=; i=1
        while [ $i -le $# ]; do
          a=$(eval echo "\${$i}")
          case $a in
            -[fvl]|-[fvl][fvl]|-[fvl][fvl][fvl]) tmp_opts="$tmp_opts$a " ;;
            --force|--volumes|--link) tmp_opts="$tmp_opts$a " ;;
          esac
          : $((i=i+1))
        done
        saved_run_cmds=$(docker inspect -f '{{index .Config.Labels "kurnia_d_win.docker.run_opts"}}' "$name" 2>/dev/null) || :
        saved_run_cmds=$(no_proc=y quote "$saved_run_cmds")
        _exec_if_fn_exists "pre_$action" || exit $?
        docker rm $tmp_opts "$name" >/dev/null || exit $?
        _exec_if_fn_exists "post_$action" || exit $?
        eval "set -- $saved_run_cmds"
        init_net=; i=1
        while [ $i -le $# ]; do
          a=$(eval echo "\${$i}")
          case $a in
          "'--network'")
            : $((i=i+1)); a=$(eval echo "\${$i}")
            init_net=${a%"'"}
            init_net=${init_net#"'"}
            break
            ;;
          esac
          : $((i=i+1))
        done
        if [ "$(docker network inspect -f '{{index .Labels "kurnia_d_win.docker.autoremove"}}{{.Containers|len}}' "$init_net" 2>/dev/null)" = true0 ]; then
          docker network rm "$init_net" >/dev/null 2>&1 || :
        fi
      fi
      exit 0
      ;;

    exec|exec_root|exec_as)
      if running "$name"; then
        _is_managed || panic "container \"$name\" is not managed"
        user=; tmp_opts='-i '
        [ -t 0 ] && [ -t 1 ] && [ -t 2 ] && tmp_opts="$tmp_opts-t " || :
        case "$action" in
          exec_root) user="0:0" ;;
          exec_as) user="${1:-}"; shift || : ;;
        esac
        [ $# = 0 ] && panic 'no command to execute'
        if [ -n "$user" ]; then
          exec docker exec $tmp_opts -u "$user" "$name" "$@"
        else
          exec docker exec $tmp_opts "$name" "$@"
        fi
        exit 1
      else
        panic 'container is not running'
      fi
      exit 0
      ;;

    kill)
      if running "$name"; then
        _is_managed || panic "container \"$name\" is not managed"
        eval "set -- $(no_proc=y quote "${kill_opts:-}" "$@")"
        tmp_opts=; i=1
        while [ $i -le $# ]; do
          a=$(eval echo "\${$i}")
          case $a in
          -s|--signal)
            : $((i=i+1)); a=$(eval echo "\${$i:-}")
            tmp_opts="$tmp_opts'--signal' $(no_proc=y count=1 quote "$a") "
            ;;
          esac
          : $((i=i+1))
        done
        eval "set -- $tmp_opts"
        exec docker kill "$@" "$name" >/dev/null
        exit 1
      else
        panic 'container is not running'
      fi
      exit 0
      ;;

    logs|port|inspect|stats|top)
      if exists container "$name"; then
        case "$action" in inspect|stats|top) set --;; esac
        exec docker "$action" "$name" "$@"
        exit 1
      else
        panic "container not exists"
      fi
      exit 0
      ;;

    status)
      if exists container "$name"; then
        _is_managed || { printf "not_docker_sh\n"; exit 0; }
        constructed_run_cmds=$(_construct_run_cmds) || exit $?
        if [ "$(docker inspect -f '{{index .Config.Labels "kurnia_d_win.docker.run_opts"}}' "$name" 2>/dev/null)" != "$constructed_run_cmds" ]; then
          printf 'different_opts '
        fi
        if [ "$(docker inspect --type image -f '{{.Id}}' "$image" 2>/dev/null)" != "$(docker inspect --type container -f '{{.Image}}' "$name" 2>/dev/null)" ]; then
          printf 'different_image '
        fi
        if running "$name"; then
          if [ "$(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null)" = "restarting" ]; then
            printf 'restarting\n'
          else
            if [ "$(docker inspect -f '{{.State.Health}}' "$name" 2>/dev/null)" = "<nil>" ]; then
              printf 'running\n'
            else
              case "$(docker inspect -f '{{.State.Health.Status}}' "$name" 2>/dev/null)" in
              "healthy")
                printf 'running\n'
                ;;
              "starting")
                printf 'starting\n'
                ;;
              *)
                printf 'not_healthy\n'
                ;;
              esac
            fi
          fi
        else
          printf 'not_running\n'
        fi
      else
        printf 'no_container\n'
      fi
      exit 0
      ;;

    show_running_cmds)
      if exists container "$name"; then
        exec docker inspect -f '{{index .Config.Labels "kurnia_d_win.docker.run_opts"}}' "$name"
        exit 1
      else
        panic "container not exists"
      fi
      exit 0
      ;;

    pull)
      _exec_if_fn_exists "pre_$action" || exit $?
      if [ "${skip_real_pull:-}" != "y" ]; then
        docker pull "$image" || exit $?
      fi
      _exec_if_fn_exists "post_$action" || exit $?
      exit 0
      ;;

    update)
      if exists container "$name"; then
        _is_managed || panic "container \"$name\" is not managed"
        pull=y; force=n
        for arg; do
          case $arg in
          -n|--nopull) pull=n ;;
          -f|--force) force=y ;;
          -nf|-fn) pull=n; force=y ;;
          esac
        done
        if [ "$pull" = "y" ]; then
          ( _main pull; ) || exit $?
        fi
        if [ "$force" = "y" ]; then
          _update || exit $?
          exit 0
        else
          case $(_main status) in
          *different_*)
            _update || exit $?
            exit 0 ;;
          esac
        fi
        exit 0
      else
        panic 'container is not exists'
      fi
      exit 0
      ;;

    ip)
      if running "$name"; then
        exec docker inspect -f \
          "{{index .NetworkSettings.Networks \"${net:-bridge}\" \"IPAddress\"}}" \
          "$name"
        exit 1
      else
        panic 'container is not running'
      fi
      exit 0
      ;;

    id)
      if exists container "$name"; then
        exec docker inspect -f '{{.Id}}' "$name"
        exit 1
      else
        panic "container not exists"
      fi
      exit 0
      ;;

    pid)
      if running "$name"; then
        exec docker inspect -f "{{.State.Pid}}" "$name"
        exit 1
      else
        panic 'container is not running'
      fi
      exit 0
      ;;

    help)
      panic "$_help_str"
      ;;

    *)
      action="command_$action"
      if type "$action" 2>/dev/null | grep -q -F function; then
        ( "$action" "$@" ) || exit $?
        exit 0
      else
        panic "$(printf '%s\n%s\n' "function \"$action\" not exists" "$_help_str")"
      fi
      exit 0
      ;;
  esac
  exit 0
}

main() (
  _main "$@"
)

# if this file is not sourced with dot (.) command
if grep -qF 6245455020934bb2ad75ce52bbdc54b7 "$0" 2>/dev/null; then
  if ! [ -r "${1:-}" ]; then
    case "${1:-}" in
    upgrade)
      set -x
      exec sh -c \
        "curl -sSLf https://raw.githubusercontent.com/payfazz/docker-sh/master/install.sh | sudo sh -s - \"$0\""
      ;;
    locate)
      exec docker inspect -f '{{index .Config.Labels "kurnia_d_win.docker.initial_spec_file"}}' "${2:-}"
      ;;
    *)  panic "Usage: $0 <file> <command> [args...]" ;;
    esac
  fi
  file=$1; shift
  [ "${file#/}" = "$file" ] && file=$PWD/$file
  dir=$(cd -P "$(dirname "$file")" && pwd)
  file="$dir/$(basename "$file")"
  filename=$(basename "$file")
  dirname=$(basename "$dir")
  dirsum=$(calc_cksum "$(hostname 2>/dev/null || :):${dir}")
  name="$dirname-$filename-$dirsum"
  name=$(printf %s "$name" | LC_ALL=C tr -cd '[:alnum:]-')
  . "$file" || panic "error processing $file"
  if [ -z "${net:-}" ] && [ "${isolate_net:-}" = "y" ]; then
    net="$dirname-$dirsum"
    net=$(printf %s "$net" | LC_ALL=C tr -cd '[:alnum:]-')
  fi
  _main "$@"
fi
