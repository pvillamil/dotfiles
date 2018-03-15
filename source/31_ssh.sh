# fix SSH connections
bind '"\e[1;5D": backward-word'
bind '"\e[1;5C": forward-word'

function install_ssh_keys() {
	  [ -z "$1" ] && {
		    echo "Need a host to connect to"
		    return 1
	  }

    # TODO regex for IP address
    #	getent hosts "$1" || {
    #		echo "Cannot resolve $1 via DNS"
    #		return 2
    #	}

    #	cat ~/work/code/svn/ops/sysadmin/ssh_keys/squiz_bris/* | \
	      cat ~/.ssh/*.pub | \
		        ssh "${1}" 'mkdir .ssh >&/dev/null; [ -f .ssh/authorized_keys ] && mv .ssh/authorized_keys .ssh/authorized_keys.$(date +%s); cat > .ssh/authorized_keys; chmod 700 .ssh; chmod 600 .ssh/authorized_keys'
}
export -f install_ssh_keys

export KEYDIR=${HOME}/key
alias keys='ls ${KEYDIR}'

#TODO this doesn't quite work and causes more trouble than it saves if enabled
_ssh-add () {
    COMPREPLY=()
    local CUR KEYS
    CUR="${COMP_WORDS[COMP_CWORD]}"
    KEYS="$(keys|egrep -v '\.pub$')"

    COMPREPLY=( ${KEYDIR}/$(compgen -W "${KEYS}" -- ${CUR}) )
    return 0
}
#complete -F _ssh-add ssh-add

function ssh() {
    local FUNCDESC="Connect to a Secure SHell, disabling any Control Master if needed by 'Dynamic', 'Local', or 'Remote' options."
	  local ARGS=()
	  local DISABLE_CONTROL_PATH=0
	  local PORT_FORWARD_OPTION_RE="^-[DLR]"

	  for ARG
	  do
		    [[ ${ARG} =~ ${PORT_FORWARD_OPTION_RE} ]] && DISABLE_CONTROL_PATH=1
		    ARGS+=("${ARG}")
	  done
	  if ((disable_control_path))
	  then
		    echo "disabling control master..."
		    ARGS=(
			      -o
			      "ControlPath none"
			      "${ARGS[@]}"
		    )
	  fi

	  command ssh "${ARGS[@]}"
}
export -f ssh

ssh-reset() {
    FUNCDESC="interactively remove the SSH control-master for specified/matching hosts"

    if [[ -z ${1} ]]; then
        error "${FUNCNAME}: must specify a host to reset, or ALL for all hosts"
        usage "${FUNCNAME} <hostname>|ALL" ${FUNCDESC}
        return 1
    fi

    if [[ ${1} =~ ALL ]]; then
        #rm -fvi ~/.ssh/*master*
        local master
        for master in $(ssh-master); do
            echo -n "${master}: "
            ssh -O exit ${master}
            done
        return  0
    else
        # rm -fvi ~/.ssh/*master*${1}*
        echo -n "${1}: "
        ssh -O exit ${1}
    fi
}
_ssh-reset() {
    COMPREPLY=()
    local cur
    cur="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=($(compgen -W "$(ssh-master)" -- ${cur}))
    return 0
}
complete -F _ssh-reset ssh-reset

function ssh-master() {
    local FUNCDESC="Show SSH control-masters."

    ls ~/.ssh/*master* |  awk -F @ '{gsub(/:22/, "", $2); print $2 }'
}
alias ssh-ls=ssh-master

function ssh-find() {
    local FUNCDESC="search for a host in SSH config"

    for PATTERN in $*; do
        grep -i ${PATTERN} ~/.ssh/config || echo "${PATTERN}: not in config"
    done
}

#SSH without a ControlMaster
alias ssh-free="ssh -S none"

function ssh-proxy() {
    local FUNCDESC="TODO: THIS DOESN'T WORK. Connect to a host via a proxy"
    local proxy target
    proxy="${1}"; echo proxy: ${proxy}
    target="${2}"; echo target: ${target}
    ssh -S none -o 'ProxyCommand ssh ${proxy} nc %h %p' ${target}
}

export SSHFS_MOUNT_POINT=~/mnt

function ssh-mount() {
    local FUNCDESC="Mount a server with SSHFS"
    local server mntdir
    server="${1}"
    mntdir="${2}"
    [[ -d ${SSHFS_MOUNT_POINT}/${server} ]] || \
      mkdir -p ${SSHFS_MOUNT_POINT}/${server}
    [[ -z $mntdir ]] && mntdir=/
    mount|grep ${server} || \
      sshfs ${server}:${mntdir} ${SSHFS_MOUNT_POINT}/${server}
}

function ssh-umount(){
    FUNCDESC="Unmount an SSHFS server mount, clean up the mount point"
    local server="${1}"
    ls ${SSHFS_MOUNT_POINT}|grep ${server} || \
      echo "$FUNCNAME: ${server}: not mounted" && return 1
    mount|grep ${server} && \
      umount ${SSHFS_MOUNT_POINT}/${server}/ && \
      rmdir ${SSHFS_MOUNT_POINT}/${server}
}

alias lsmnt='ls ${SSHFS_MOUNT_POINT}'
