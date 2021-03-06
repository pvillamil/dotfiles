# Functions of functions

### MJL20170222 utility functions.
function error() {
    local FUNCDESC='Echo arguments to STDERR'
    if [[ -z ${1} ]]; then
        usage "${FUCNAME} <message> [<more messages>]" ${FUNCDESC}
        return 1
    fi
    >&2 echo ${@}
}

function usage() {
    local FUNCDESC='Show instructions for using a function.

The first argument is a string describing how to use a function. There can be
multiple usage string arguments. All will be strung together and folded at the
terminal width.

The LAST argument is taken to be a string describing what the function does. It
is useful to keep this in a $FUNCDESC variable and pass it as the last argument
to usage().'

    USAGE="${1}"; shift
    if [[ -z "${1}" ]]; then
        usage "${FUNCNAME} <instruction> [<strings>] <description>" ${FUNCDESC}
        return 1
    fi
    MESSAGE="${@}"
    error Usage: ${USAGE}
    echo ${MESSAGE} | fold -s -w ${COLUMNS}
}

function is_exe() {
    local FUNCDESC="Test if all arguments are runnable commands"
    type -p "${@}" > /dev/null
}

function is_linux() {
    local FUNCDESC="Test if the operating system is a Linux flavour"
    [[ $(uname) =~ Linux ]] || return 1
}

### MJL20180314 Function introspection

alias debugon='shopt -s extdebug'
alias debugoff='shopt -u extdebug'

function functions() {
    local FUNCDESC='Prints the names of all defined shell functions.

By default this will list all "interactive" functions designed to be called from
a shell prompt. If the optional argument -a or --all is supplied then functions
starting with an underscore are also printed.'

    if [[ "${1}" == "-a" ]] || [[ "${1}" == "--all" ]]; then
        declare -F|awk '{print $3}'
    else
        declare -F|awk '!/declare -f _/{print $3}'
    fi
}
alias fns=functions
# MJL20180314 Bash completion for meta-functions
_fns() {
    COMPREPLY=()
    local cur words
    cur="${COMP_WORDS[COMP_CWORD]}"
    words="$(functions --all)"
    COMPREPLY=($(compgen -W "${words}" -- ${cur}))
    return 0
}

function describe() {
    local FUNCDESC='Describe a function and show where it is defined.

Prints information about the specified function including the first line of the
$FUNCDESC declaration from the function definition, and where the function is
defined.

This function requires shopt -s extdebug to show file and line details.'

    if [[ -z "${1}" ]]; then
        usage "${FUNCNAME} <function>" ${FUNCDESC}
        error "Must supply a function or executable to describe."
        return 1
    fi
    case $(type -t "${1}" 2> /dev/null) in
        alias)
            #piping grep to awk and seding the output is usually not great, but
            #awk can't search for or match a bash variable?
            \grep -Rn "alias ${1}=" ${DOTFILES}/source \
                | awk -F: '{print "⍺:\t" $3 "\t--> " $1 ":" $2}' \
                    | sed "s/${1}=//g"
            return $?
            ;;
        function)
            local toggled=0
            shopt extdebug > /dev/null || shopt -s extdebug && toggled=1

            declare -F "${1}" \
                | awk '{print "λ:\tfunction " $1 "\t--> " $3 ":" $2}'
            type -a "${1}" | awk -F = '/FUNCDESC/{print "    "$2;exit}' \
                | fold -s -w ${COLUMNS}

            [[ $toggled == 1 ]] && shopt -u extdebug
            ;;
        file)
            echo -en "◆:\t"
            file $(which ${1}) | awk -F ': ' '{print $2 "\t--> " $1}' \
                | fold -s -w ${COLUMNS}
            ;;
        builtin|keyword)
            echo -en "β:\t"
            type ${1} 2>&1 |sed $'s/bash://g; s/type://g; s/is a/\t--> /g;'
            ;;
        '')
            error "${FUNCNAME}: ${1}: command not found"
            return 2
    esac
}
complete -F _command describe

function codeit() {
    local FUNCDESC="Edit a command in VS-Code.

Uses describe() to find the command and then opens the source file at the line
number. Will also work with commands which are files."

# There doesn't appear to be a general way to tell $EDITOR to go to a specific
# line, so I had to choose one editor for this shell function. I chose Code,
# which understands the path/to/file:linenumber format output by describe()."

    if [[ -z "${1}" ]]; then
        usage "${FUNCNAME} <command>" ${FUNCDESC}
        error "${FUNCNAME}: Must supply a command to edit"
        return 1
    fi

    local COMMAND=$(describe ${1} 2> /dev/null |awk '{print $NF}')

    case ${COMMAND} in
        '')
            error "${FUNCNAME}: ${1}: command not found"
            return 2
            ;;
        builtin|keyword)
            error "${FUNCNAME}: '${1}' is a shell builtin/keyword."
            return 3
            ;;
        *)
            code -g ${COMMAND}
    esac
}
complete -F _command codeit

function list() {
  local FUNCDESC='Print a listing of a function definition.

The specified function is described and then listed.'

  if [[ -z "${1}" ]]; then
      usage "${FUNCNAME} <function>" ${FUNCDESC}
      error "Must supply a function or script to list."
      return 1
  fi

  describe ${1}

  if [[ $(type "${1}") =~ function ]]; then
        if is_exe pygmentize ; then
            type -a "${1}"|tail -n +2 \
              |pygmentize -O encoding=utf8 -f terminal -l bash \
              |less -R
        else
            type -a "${1}"|tail -n +2|less -R
        fi
  elif  [[ -f $(which "${1}") || -s $(which "${1}") ]]; then
      less -R $(which "${1}") \
        |grep -v 'switch off syntax highlighting' \
        |less
  fi
}
complete -F _fns list

function defined() {
    local FUNCDESC="Show environment variable dotfile definition.

This shows where in DOTFILES the variable was declared, and how. This could be
different to the variable's current definition. If the variable was not
declared in DOTFILES then there will be no output."

    if [[ -z "${1}" ]]; then
        usage "${FUNCNAME} <variable>" ${FUNCDESC}
        error "Must supply a variable to look up."
        return 1
    fi

    \grep -Rn "${1}=" $DOTFILES/init/ $DOTFILES/source 2>/dev/null  |\
      grep -v alias |\
      awk -F: '{print "∈ var: " $3 "\t--> " $1 ":" $2}'
}
_vars() {
    COMPREPLY=()
    local cur words
    cur="${COMP_WORDS[COMP_CWORD]}"
    words="$(env|awk -F= '/=/{print $1}')"
    COMPREPLY=($(compgen -W "${words}" -- ${cur}))
    return 0
}
complete -F _vars defined

function load(){
    local FUNCDESC="Load (source) file(s) into the bash environment.

Only loads if the file is present. Silently ignores missing files."

    if [[ -z "${1}" ]] ; then
        error $"${FUNCNAME}: must specify a file to load"
        usage "${FUNCNAME} <file> [<file>]..."  ${FUNCDESC}
        return 1
    fi

    local MODULE
    for MODULE in "${@}"; do
        if [[ -f "${MODULE}" ]] || [[ -s "${MODULE}" ]]; then
            is_bashrc_debug && echo "${MODULE}"
            source "${MODULE}"
        fi
    done
}

## MJL20180314 PATH manipulation

function path_add() {
    local FUNCDESC='Add an entry to $PATH, but ONLY if dir exists AND not already in $PATH.

If second parameter is specified (any value), PREPEND (to front of $PATH) rather
than Append.'
    if [[ -z "${1}" ]]; then
        usage "${FUNCNAME} directory [prepend]" ${FUNCDESC}
        return 1
    fi
    if [ -d "$1" ] && [[ ":${PATH}:" != *":${1}:"* ]]; then
        if [ -z ${2} ]; then
            PATH="${PATH:+"${PATH}:"}${1}"
        else
            PATH="${1}:${PATH}"
        fi
    fi
}

# Remove an entry from $PATH
# Based on http://stackoverflow.com/a/2108540/142339
# MJL20171015 This is an actual function of it's argument. Use
#             path_remove for interactive use with side-effect
function __path_remove() {

  local ARG path
  path=":$PATH:"
  for ARG in "${@}"; do path="${path//:${ARG}:/:}"; done
  path="${path%:}"
  path="${path#:}"
  echo "$path"
}

function path_remove() {
    local FUNCDESC='Remove an entry from $PATH.
All occurrences of the entry will be removed immediately.'
    if [[ -z "${1}" ]]; then
        usage "${FUNCNAME} directory" ${FUNCDESC}
        return 1
    fi
    PATH=$(__path_remove "${1}")
}
