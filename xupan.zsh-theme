CURRENT_BG='NONE'

# Characters
SEGMENT_SEPARATOR="\ue0b0"
PLUSMINUS="\u00b1"
BRANCH="\ue0a0"
DETACHED="\u27a6"
CROSS="\u2718"
LIGHTNING="\u26a1"
GEAR="\u2699"


# Debug
[[ -n $DEBUG ]] && set -x
# Default values for the prompt
# Override these values in ~/.zshrc or ~/.bashrc
KUBE_PS1_BINARY="${KUBE_PS1_BINARY:-kubectl}"
KUBE_PS1_SYMBOL_ENABLE="${KUBE_PS1_SYMBOL_ENABLE:-true}"
KUBE_PS1_SYMBOL_DEFAULT=${KUBE_PS1_SYMBOL_DEFAULT:-$'\u2388 '}
KUBE_PS1_SYMBOL_USE_IMG=true
KUBE_PS1_NS_ENABLE="${KUBE_PS1_NS_ENABLE:-true}"
KUBE_PS1_PREFIX=""
KUBE_PS1_SEPARATOR="${KUBE_PS1_SEPARATOR-|}"
KUBE_PS1_DIVIDER="${KUBE_PS1_DIVIDER-:}"
KUBE_PS1_SUFFIX=""
KUBE_PS1_SYMBOL_COLOR="${KUBE_PS1_SYMBOL_COLOR-blue}"
KUBE_PS1_CTX_COLOR="${KUBE_PS1_CTX_COLOR-red}"
KUBE_PS1_NS_COLOR="${KUBE_PS1_NS_COLOR-cyan}"
KUBE_PS1_BG_COLOR="${KUBE_PS1_BG_COLOR}"
KUBE_PS1_KUBECONFIG_CACHE="${KUBECONFIG}"
KUBE_PS1_DISABLE_PATH="${HOME}/.kube/kube-ps1/disabled"
KUBE_PS1_LAST_TIME=0
KUBE_PS1_CLUSTER_FUNCTION="${KUBE_PS1_CLUSTER_FUNCTION}"
KUBE_PS1_NAMESPACE_FUNCTION="${KUBE_PS1_NAMESPACE_FUNCTION}"

# Determine our shell
if [ "${ZSH_VERSION-}" ]; then
  KUBE_PS1_SHELL="zsh"
elif [ "${BASH_VERSION-}" ]; then
  KUBE_PS1_SHELL="bash"
fi

_kube_ps1_init() {
  [[ -f "${KUBE_PS1_DISABLE_PATH}" ]] && KUBE_PS1_ENABLED=off

  case "${KUBE_PS1_SHELL}" in
    "zsh")
      _KUBE_PS1_OPEN_ESC="%{"
      _KUBE_PS1_CLOSE_ESC="%}"
      _KUBE_PS1_DEFAULT_BG="%k"
      _KUBE_PS1_DEFAULT_FG="%f"
      setopt PROMPT_SUBST
      autoload -U add-zsh-hook
      add-zsh-hook precmd _kube_ps1_update_cache
      zmodload -F zsh/stat b:zstat
      zmodload zsh/datetime
      ;;
    "bash")
      _KUBE_PS1_OPEN_ESC=$'\001'
      _KUBE_PS1_CLOSE_ESC=$'\002'
      _KUBE_PS1_DEFAULT_BG=$'\033[49m'
      _KUBE_PS1_DEFAULT_FG=$'\033[39m'
      PROMPT_COMMAND="_kube_ps1_update_cache;${PROMPT_COMMAND:-:}"
      ;;
  esac
}

_kube_ps1_color_fg() {
  local KUBE_PS1_FG_CODE
  case "${1}" in
    black) KUBE_PS1_FG_CODE=0;;
    red) KUBE_PS1_FG_CODE=1;;
    green) KUBE_PS1_FG_CODE=2;;
    yellow) KUBE_PS1_FG_CODE=3;;
    blue) KUBE_PS1_FG_CODE=4;;
    magenta) KUBE_PS1_FG_CODE=5;;
    cyan) KUBE_PS1_FG_CODE=6;;
    white) KUBE_PS1_FG_CODE=7;;
    # 256
    [0-9]|[1-9][0-9]|[1][0-9][0-9]|[2][0-4][0-9]|[2][5][0-6]) KUBE_PS1_FG_CODE="${1}";;
    *) KUBE_PS1_FG_CODE=default
  esac

  if [[ "${KUBE_PS1_FG_CODE}" == "default" ]]; then
    KUBE_PS1_FG_CODE="${_KUBE_PS1_DEFAULT_FG}"
    return
  elif [[ "${KUBE_PS1_SHELL}" == "zsh" ]]; then
    KUBE_PS1_FG_CODE="%F{$KUBE_PS1_FG_CODE}"
  elif [[ "${KUBE_PS1_SHELL}" == "bash" ]]; then
    if tput setaf 1 &> /dev/null; then
      KUBE_PS1_FG_CODE="$(tput setaf ${KUBE_PS1_FG_CODE})"
    elif [[ $KUBE_PS1_FG_CODE -ge 0 ]] && [[ $KUBE_PS1_FG_CODE -le 256 ]]; then
      KUBE_PS1_FG_CODE="\033[38;5;${KUBE_PS1_FG_CODE}m"
    else
      KUBE_PS1_FG_CODE="${_KUBE_PS1_DEFAULT_FG}"
    fi
  fi
  echo ${_KUBE_PS1_OPEN_ESC}${KUBE_PS1_FG_CODE}${_KUBE_PS1_CLOSE_ESC}
}

_kube_ps1_color_bg() {
  local KUBE_PS1_BG_CODE
  case "${1}" in
    black) KUBE_PS1_BG_CODE=0;;
    red) KUBE_PS1_BG_CODE=1;;
    green) KUBE_PS1_BG_CODE=2;;
    yellow) KUBE_PS1_BG_CODE=3;;
    blue) KUBE_PS1_BG_CODE=4;;
    magenta) KUBE_PS1_BG_CODE=5;;
    cyan) KUBE_PS1_BG_CODE=6;;
    white) KUBE_PS1_BG_CODE=7;;
    # 256
    [0-9]|[1-9][0-9]|[1][0-9][0-9]|[2][0-4][0-9]|[2][5][0-6]) KUBE_PS1_BG_CODE="${1}";;
    *) KUBE_PS1_BG_CODE=$'\033[0m';;
  esac

  if [[ "${KUBE_PS1_BG_CODE}" == "default" ]]; then
    KUBE_PS1_FG_CODE="${_KUBE_PS1_DEFAULT_BG}"
    return
  elif [[ "${KUBE_PS1_SHELL}" == "zsh" ]]; then
    KUBE_PS1_BG_CODE="%K{$KUBE_PS1_BG_CODE}"
  elif [[ "${KUBE_PS1_SHELL}" == "bash" ]]; then
    if tput setaf 1 &> /dev/null; then
      KUBE_PS1_BG_CODE="$(tput setab ${KUBE_PS1_BG_CODE})"
    elif [[ $KUBE_PS1_BG_CODE -ge 0 ]] && [[ $KUBE_PS1_BG_CODE -le 256 ]]; then
      KUBE_PS1_BG_CODE="\033[48;5;${KUBE_PS1_BG_CODE}m"
    else
      KUBE_PS1_BG_CODE="${DEFAULT_BG}"
    fi
  fi
  echo ${OPEN_ESC}${KUBE_PS1_BG_CODE}${CLOSE_ESC}
}

_kube_ps1_binary_check() {
  command -v $1 >/dev/null
}

_kube_ps1_symbol() {
  [[ "${KUBE_PS1_SYMBOL_ENABLE}" == false ]] && return

  case "${KUBE_PS1_SHELL}" in
    bash)
      if ((BASH_VERSINFO[0] >= 4)) && [[ $'\u2388 ' != "\\u2388 " ]]; then
        KUBE_PS1_SYMBOL="${KUBE_PS1_SYMBOL_DEFAULT}"
        # KUBE_PS1_SYMBOL=$'\u2388 '
        KUBE_PS1_SYMBOL_IMG=$'\u2638 '
      else
        KUBE_PS1_SYMBOL=$'\xE2\x8E\x88 '
        KUBE_PS1_SYMBOL_IMG=$'\xE2\x98\xB8 '
      fi
      ;;
    zsh)
      KUBE_PS1_SYMBOL="${KUBE_PS1_SYMBOL_DEFAULT}"
      KUBE_PS1_SYMBOL_IMG="\u2638 ";;
    *)
      KUBE_PS1_SYMBOL="k8s"
  esac

  if [[ "${KUBE_PS1_SYMBOL_USE_IMG}" == true ]]; then
    KUBE_PS1_SYMBOL="${KUBE_PS1_SYMBOL_IMG}"
  fi

  echo "${KUBE_PS1_SYMBOL}"
}

_kube_ps1_split() {
  type setopt >/dev/null 2>&1 && setopt SH_WORD_SPLIT
  local IFS=$1
  echo $2
}

_kube_ps1_file_newer_than() {
  local mtime
  local file=$1
  local check_time=$2

  if [[ "${KUBE_PS1_SHELL}" == "zsh" ]]; then
    mtime=$(zstat -L +mtime "${file}")
  elif stat -c "%s" /dev/null &> /dev/null; then
    # GNU stat
    mtime=$(stat -L -c %Y "${file}")
  else
    # BSD stat
    mtime=$(stat -L -f %m "$file")
  fi

  [[ "${mtime}" -gt "${check_time}" ]]
}

_kube_ps1_update_cache() {
  [[ "${KUBE_PS1_ENABLED}" == "off" ]] && return

  if ! _kube_ps1_binary_check "${KUBE_PS1_BINARY}"; then
    # No ability to fetch context/namespace; display N/A.
    KUBE_PS1_CONTEXT="BINARY-N/A"
    KUBE_PS1_NAMESPACE="N/A"
    return
  fi

  if [[ "${KUBECONFIG}" != "${KUBE_PS1_KUBECONFIG_CACHE}" ]]; then
    # User changed KUBECONFIG; unconditionally refetch.
    KUBE_PS1_KUBECONFIG_CACHE=${KUBECONFIG}
    _kube_ps1_get_context_ns
    return
  fi

  # kubectl will read the environment variable $KUBECONFIG
  # otherwise set it to ~/.kube/config
  local conf
  for conf in $(_kube_ps1_split : "${KUBECONFIG:-${HOME}/.kube/config}"); do
    [[ -r "${conf}" ]] || continue
    if _kube_ps1_file_newer_than "${conf}" "${KUBE_PS1_LAST_TIME}"; then
      _kube_ps1_get_context_ns
      return
    fi
  done
}

# TODO: Break this function apart:
#       one for context and one for namespace
_kube_ps1_get_context_ns() {
  # Set the command time
  if [[ "${KUBE_PS1_SHELL}" == "bash" ]]; then
    if ((BASH_VERSINFO[0] >= 4)); then
      KUBE_PS1_LAST_TIME=$(printf '%(%s)T')
    else
      KUBE_PS1_LAST_TIME=$(date +%s)
    fi
  elif [[ "${KUBE_PS1_SHELL}" == "zsh" ]]; then
    KUBE_PS1_LAST_TIME=$EPOCHSECONDS
  fi

  KUBE_PS1_CONTEXT="$(${KUBE_PS1_BINARY} config current-context 2>/dev/null)"

  if [[ ! -z "${KUBE_PS1_CLUSTER_FUNCTION}" ]]; then
    KUBE_PS1_CONTEXT=$($KUBE_PS1_CLUSTER_FUNCTION $KUBE_PS1_CONTEXT)
  fi

  if [[ -z "${KUBE_PS1_CONTEXT}" ]]; then
    KUBE_PS1_CONTEXT="N/A"
    KUBE_PS1_NAMESPACE="N/A"
    return
  elif [[ "${KUBE_PS1_NS_ENABLE}" == true ]]; then
    KUBE_PS1_NAMESPACE="$(${KUBE_PS1_BINARY} config view --minify --output 'jsonpath={..namespace}' 2>/dev/null)"
    # Set namespace to 'default' if it is not defined
    KUBE_PS1_NAMESPACE="${KUBE_PS1_NAMESPACE:-default}"

    if [[ ! -z "${KUBE_PS1_NAMESPACE_FUNCTION}" ]]; then
        KUBE_PS1_NAMESPACE=$($KUBE_PS1_NAMESPACE_FUNCTION $KUBE_PS1_NAMESPACE)
    fi

  fi
}

# Set kube-ps1 shell defaults
_kube_ps1_init

_kubeon_usage() {
  cat <<"EOF"
Toggle kube-ps1 prompt on

Usage: kubeon [-g | --global] [-h | --help]

With no arguments, turn off kube-ps1 status for this shell instance (default).

  -g --global  turn on kube-ps1 status globally
  -h --help    print this message
EOF
}

_kubeoff_usage() {
  cat <<"EOF"
Toggle kube-ps1 prompt off

Usage: kubeoff [-g | --global] [-h | --help]

With no arguments, turn off kube-ps1 status for this shell instance (default).

  -g --global turn off kube-ps1 status globally
  -h --help   print this message
EOF
}

kubeon() {
  if [[ "${1}" == '-h' || "${1}" == '--help' ]]; then
    _kubeon_usage
  elif [[ "${1}" == '-g' || "${1}" == '--global' ]]; then
    rm -f -- "${KUBE_PS1_DISABLE_PATH}"
  elif [[ "$#" -ne 0 ]]; then
    echo -e "error: unrecognized flag ${1}\\n"
    _kubeon_usage
    return
  fi

  KUBE_PS1_ENABLED=on
}

kubeoff() {
  if [[ "${1}" == '-h' || "${1}" == '--help' ]]; then
    _kubeoff_usage
  elif [[ "${1}" == '-g' || "${1}" == '--global' ]]; then
    mkdir -p -- "$(dirname "${KUBE_PS1_DISABLE_PATH}")"
    touch -- "${KUBE_PS1_DISABLE_PATH}"
  elif [[ $# -ne 0 ]]; then
    echo "error: unrecognized flag ${1}" >&2
    _kubeoff_usage
    return
  fi

  KUBE_PS1_ENABLED=off
}

# Build our prompt
kube_ps1() {
  [[ "${KUBE_PS1_ENABLED}" == "off" ]] && return
  [[ -z "${KUBE_PS1_CONTEXT}" ]] && return

  local KUBE_PS1
  local KUBE_PS1_RESET_COLOR="${_KUBE_PS1_OPEN_ESC}${_KUBE_PS1_DEFAULT_FG}${_KUBE_PS1_CLOSE_ESC}"

  # Background Color
  [[ -n "${KUBE_PS1_BG_COLOR}" ]] && KUBE_PS1+="$(_kube_ps1_color_bg ${KUBE_PS1_BG_COLOR})"

  # Prefix
  [[ -n "${KUBE_PS1_PREFIX}" ]] && KUBE_PS1+="${KUBE_PS1_PREFIX}"

  # Symbol
  KUBE_PS1+="$(_kube_ps1_color_fg $KUBE_PS1_SYMBOL_COLOR)$(_kube_ps1_symbol)${KUBE_PS1_RESET_COLOR}"

  if [[ -n "${KUBE_PS1_SEPARATOR}" ]] && [[ "${KUBE_PS1_SYMBOL_ENABLE}" == true ]]; then
    KUBE_PS1+="${KUBE_PS1_SEPARATOR}"
  fi

  # Context
  KUBE_PS1+="$(_kube_ps1_color_fg $KUBE_PS1_CTX_COLOR)${KUBE_PS1_CONTEXT}${KUBE_PS1_RESET_COLOR}"

  # Namespace
  if [[ "${KUBE_PS1_NS_ENABLE}" == true ]]; then
    if [[ -n "${KUBE_PS1_DIVIDER}" ]]; then
      KUBE_PS1+="${KUBE_PS1_DIVIDER}"
    fi
    KUBE_PS1+="$(_kube_ps1_color_fg ${KUBE_PS1_NS_COLOR})${KUBE_PS1_NAMESPACE}${KUBE_PS1_RESET_COLOR}"
  fi

  # Suffix
  [[ -n "${KUBE_PS1_SUFFIX}" ]] && KUBE_PS1+="${KUBE_PS1_SUFFIX}"

  # Close Background color if defined
  [[ -n "${KUBE_PS1_BG_COLOR}" ]] && KUBE_PS1+="${_KUBE_PS1_OPEN_ESC}${_KUBE_PS1_DEFAULT_BG}${_KUBE_PS1_CLOSE_ESC}"

  echo "${KUBE_PS1}"
}



# Begin a segment
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.
prompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
    print -n " %{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%} "
  else
    print -n "%{$bg%}%{$fg%} "
  fi
  CURRENT_BG=$1
  [[ -n $3 ]] && print -n $3
}

# End the prompt, closing any open segments
prompt_end() {
  if [[ -n $CURRENT_BG ]]; then
    print -n " %{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
  else
    print -n "%{%k%}"
  fi
  print -n "%{%f%}"
  CURRENT_BG=''
}


### Prompt components
# Each component will draw itself, and hide itself if no information needs to be shown

# Context: user@hostname (who am I and where am I)
prompt_context() {
  if [[ -n "$SSH_CLIENT" ]]; then
    prompt_segment magenta white "%{$fg_bold[white]%(!.%{%F{white}%}.)%}$USER@%m%{$fg_no_bold[white]%}"
  else
    prompt_segment black white "%{$fg_bold[white]%(!.%{%F{white}%}.)%}%n%f@%M%f%{$fg_no_bold[white]%}"
  fi
}

# Battery Level
prompt_battery() {
  HEART='♥ '

  if [[ $(uname) == "Darwin" ]] ; then

    function battery_is_charging() {
      [ $(ioreg -rc AppleSmartBattery | grep -c '^.*"ExternalConnected"\ =\ No') -eq 1 ]
    }

    function battery_pct() {
      local smart_battery_status="$(ioreg -rc "AppleSmartBattery")"
      typeset -F maxcapacity=$(echo $smart_battery_status | grep '^.*"MaxCapacity"\ =\ ' | sed -e 's/^.*"MaxCapacity"\ =\ //')
      typeset -F currentcapacity=$(echo $smart_battery_status | grep '^.*"CurrentCapacity"\ =\ ' | sed -e 's/^.*CurrentCapacity"\ =\ //')
      integer i=$(((currentcapacity/maxcapacity) * 100))
      echo $i
    }

    function battery_pct_remaining() {
      if battery_is_charging ; then
        battery_pct
      else
        echo "External Power"
      fi
    }

    function battery_time_remaining() {
      local smart_battery_status="$(ioreg -rc "AppleSmartBattery")"
      if [[ $(echo $smart_battery_status | grep -c '^.*"ExternalConnected"\ =\ No') -eq 1 ]] ; then
        timeremaining=$(echo $smart_battery_status | grep '^.*"AvgTimeToEmpty"\ =\ ' | sed -e 's/^.*"AvgTimeToEmpty"\ =\ //')
        if [ $timeremaining -gt 720 ] ; then
          echo "::"
        else
          echo "~$((timeremaining / 60)):$((timeremaining % 60))"
        fi
      fi
    }

    b=$(battery_pct_remaining)
    if [[ $(ioreg -rc AppleSmartBattery | grep -c '^.*"ExternalConnected"\ =\ No') -eq 1 ]] ; then
      if [ $b -gt 50 ] ; then
        prompt_segment green white
      elif [ $b -gt 20 ] ; then
        prompt_segment yellow white
      else
        prompt_segment red white
      fi
      echo -n "%{$fg_bold[white]%}$HEART$(battery_pct_remaining)%%%{$fg_no_bold[white]%}"
    fi
  fi

  if [[ $(uname) == "Linux" && -d /sys/module/battery ]] ; then

    function battery_is_charging() {
      ! [[ $(acpi 2&>/dev/null | grep -c '^Battery.*Discharging') -gt 0 ]]
    }

    function battery_pct() {
      if (( $+commands[acpi] )) ; then
        echo "$(acpi | cut -f2 -d ',' | tr -cd '[:digit:]')"
      fi
    }

    function battery_pct_remaining() {
      if [ ! $(battery_is_charging) ] ; then
        battery_pct
      else
        echo "External Power"
      fi
    }

    function battery_time_remaining() {
      if [[ $(acpi 2&>/dev/null | grep -c '^Battery.*Discharging') -gt 0 ]] ; then
        echo $(acpi | cut -f3 -d ',')
      fi
    }

    b=$(battery_pct_remaining)
    if [[ $(acpi 2&>/dev/null | grep -c '^Battery.*Discharging') -gt 0 ]] ; then
      if [ $b -gt 40 ] ; then
        prompt_segment green white
      elif [ $b -gt 20 ] ; then
        prompt_segment yellow white
      else
        prompt_segment red white
      fi
      echo -n "%{$fg_bold[white]%}$HEART$(battery_pct_remaining)%%%{$fg_no_bold[white]%}"
    fi

  fi
}

# Git: branch/detached head, dirty status
prompt_git() {
#«»±˖˗‑‐‒ ━ ✚‐↔←↑↓→↭⇎⇔⋆━◂▸◄►◆☀★☗☊✔✖❮❯⚑⚙
  local PL_BRANCH_CHAR
  () {
    local LC_ALL="" LC_CTYPE="en_US.UTF-8"
    PL_BRANCH_CHAR="$BRANCH"
  }
  local ref dirty mode repo_path clean has_upstream
  local modified untracked added deleted tagged stashed
  local ready_commit git_status bgclr fgclr
  local commits_diff commits_ahead commits_behind has_diverged to_push to_pull

  repo_path=$(git rev-parse --git-dir 2>/dev/null)

  if $(git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
    dirty=$(parse_git_dirty)
    git_status=$(git status --porcelain 2> /dev/null)
    ref=$(git symbolic-ref HEAD 2> /dev/null) || ref="➦ $(git rev-parse --short HEAD 2> /dev/null)"
    if [[ -n $dirty ]]; then
      clean=''
      bgclr='yellow'
      fgclr='black'
    else
      clean=' ✔'
      bgclr='green'
      fgclr='white'
    fi

    local upstream=$(git rev-parse --symbolic-full-name --abbrev-ref @{upstream} 2> /dev/null)
    if [[ -n "${upstream}" && "${upstream}" != "@{upstream}" ]]; then has_upstream=true; fi

    local current_commit_hash=$(git rev-parse HEAD 2> /dev/null)

    local number_of_untracked_files=$(\grep -c "^??" <<< "${git_status}")
    # if [[ $number_of_untracked_files -gt 0 ]]; then untracked=" $number_of_untracked_files◆"; fi
    if [[ $number_of_untracked_files -gt 0 ]]; then untracked=" $number_of_untracked_files☀"; fi

    local number_added=$(\grep -c "^A" <<< "${git_status}")
    if [[ $number_added -gt 0 ]]; then added=" $number_added✚"; fi

    local number_modified=$(\grep -c "^.M" <<< "${git_status}")
    if [[ $number_modified -gt 0 ]]; then
      modified=" $number_modified●"
      bgclr='red'
      fgclr='white'
    fi

    local number_added_modified=$(\grep -c "^M" <<< "${git_status}")
    local number_added_renamed=$(\grep -c "^R" <<< "${git_status}")
    if [[ $number_modified -gt 0 && $number_added_modified -gt 0 ]]; then
      modified="$modified$((number_added_modified+number_added_renamed))±"
    elif [[ $number_added_modified -gt 0 ]]; then
      modified=" ●$((number_added_modified+number_added_renamed))±"
    fi

    local number_deleted=$(\grep -c "^.D" <<< "${git_status}")
    if [[ $number_deleted -gt 0 ]]; then
      deleted=" $number_deleted‒"
      bgclr='red'
      fgclr='white'
    fi

    local number_added_deleted=$(\grep -c "^D" <<< "${git_status}")
    if [[ $number_deleted -gt 0 && $number_added_deleted -gt 0 ]]; then
      deleted="$deleted$number_added_deleted±"
    elif [[ $number_added_deleted -gt 0 ]]; then
      deleted=" ‒$number_added_deleted±"
    fi

    local tag_at_current_commit=$(git describe --exact-match --tags $current_commit_hash 2> /dev/null)
    if [[ -n $tag_at_current_commit ]]; then tagged=" ☗$tag_at_current_commit "; fi

    local number_of_stashes="$(git stash list -n1 2> /dev/null | wc -l)"
    if [[ $number_of_stashes -gt 0 ]]; then
      stashed=" ${number_of_stashes##*(  )}⚙"
      bgclr='magenta'
      fgclr='white'
    fi

    if [[ $number_added -gt 0 || $number_added_modified -gt 0 || $number_added_deleted -gt 0 ]]; then ready_commit=' ⚑'; fi

    local upstream_prompt=''
    if [[ $has_upstream == true ]]; then
      commits_diff="$(git log --pretty=oneline --topo-order --left-right ${current_commit_hash}...${upstream} 2> /dev/null)"
      commits_ahead=$(\grep -c "^<" <<< "$commits_diff")
      commits_behind=$(\grep -c "^>" <<< "$commits_diff")
      upstream_prompt="$(git rev-parse --symbolic-full-name --abbrev-ref @{upstream} 2> /dev/null)"
      upstream_prompt=$(sed -e 's/\/.*$/ ☊ /g' <<< "$upstream_prompt")
    fi

    has_diverged=false
    if [[ $commits_ahead -gt 0 && $commits_behind -gt 0 ]]; then has_diverged=true; fi
    if [[ $has_diverged == false && $commits_ahead -gt 0 ]]; then
      if [[ $bgclr == 'red' || $bgclr == 'magenta' ]] then
        to_push=" $fg_bold[white]↑$commits_ahead$fg_bold[$fgclr]"
      else
        to_push=" $fg_bold[black]↑$commits_ahead$fg_bold[$fgclr]"
      fi
    fi
    if [[ $has_diverged == false && $commits_behind -gt 0 ]]; then to_pull=" $fg_bold[magenta]↓$commits_behind$fg_bold[$fgclr]"; fi

    if [[ -e "${repo_path}/BISECT_LOG" ]]; then
      mode=" <B>"
    elif [[ -e "${repo_path}/MERGE_HEAD" ]]; then
      mode=" >M<"
    elif [[ -e "${repo_path}/rebase" || -e "${repo_path}/rebase-apply" || -e "${repo_path}/rebase-merge" || -e "${repo_path}/../.dotest" ]]; then
      mode=" >R>"
    fi

    prompt_segment $bgclr $fgclr

    print -n "%{$fg_bold[$fgclr]%}${ref/refs\/heads\//$PL_BRANCH_CHAR $upstream_prompt}${mode}$to_push$to_pull$clean$tagged$stashed$untracked$modified$deleted$added$ready_commit%{$fg_no_bold[$fgclr]%}"
  fi
}

prompt_hg() {
  local rev status
  if $(hg id >/dev/null 2>&1); then
    if $(hg prompt >/dev/null 2>&1); then
      if [[ $(hg prompt "{status|unknown}") = "?" ]]; then
        # if files are not added
        prompt_segment red white
        st='±'
      elif [[ -n $(hg prompt "{status|modified}") ]]; then
        # if any modification
        prompt_segment yellow black
        st='±'
      else
        # if working copy is clean
        prompt_segment green black
      fi
      print -n $(hg prompt "☿ {rev}@{branch}") $st
    else
      st=""
      rev=$(hg id -n 2>/dev/null | sed 's/[^-0-9]//g')
      branch=$(hg id -b 2>/dev/null)
      if `hg st | grep -q "^\?"`; then
        prompt_segment red black
        st='±'
      elif `hg st | grep -q "^[MA]"`; then
        prompt_segment yellow black
        st='±'
      else
        prompt_segment green black
      fi
      print -n "☿ $rev@$branch" $st
    fi
  fi
}

# Dir: current working directory
prompt_dir() {
  prompt_segment blue white "%{$fg_bold[white]%}%~%{$fg_no_bold[white]%}"
}

# Virtualenv: current working virtualenv
prompt_virtualenv() {
  local virtualenv_path="$VIRTUAL_ENV"
  if [[ -n $virtualenv_path && -n $VIRTUAL_ENV_DISABLE_PROMPT ]]; then
    prompt_segment blue black "(`basename $virtualenv_path`)"
  fi
}

prompt_time() {
  prompt_segment black white "%{$fg_bold[white]%}%D{%D %T}%{$fg_no_bold[white]%}"
}

# Status:
# - was there an error
# - am I root
# - are there background jobs?
prompt_status() {
  local symbols
  symbols=()
  [[ $RETVAL -ne 0 ]] && symbols+="%{%F{red}%}$CROSS"
  [[ $UID -eq 0 ]] && symbols+="%{%F{yellow}%}$LIGHTNING"
  [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{cyan}%}$GEAR"

  [[ -n "$symbols" ]] && prompt_segment black default "$symbols"
}

prompt_kube(){
  prompt_segment black white "%{$fg_bold[white]%}$(kube_ps1)%{$fg_no_bold[white]%}"
}

## Main prompt
build_prompt() {
  RETVAL=$?
  print -n "\n"
  print -n "┌─"
  prompt_status
  prompt_battery
  prompt_virtualenv
  prompt_dir
  prompt_git
  prompt_hg
  prompt_end
  print -n "\n"
  print -n "| "
  CURRENT_BG='NONE'
  prompt_kube
  prompt_context
  prompt_time
  prompt_end
  print -n "\n"
  print -n "└────➤"
}

PROMPT='%{%f%b%k%}$(build_prompt) '
