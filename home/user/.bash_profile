
[ -z "$PS1" ] && return

test -z "$_IN_BASH_PROFILE" || return
_IN_BASH_PROFILE=1

HISTCONTROL=ignoreboth
HISTTIMEFORMAT="%Y%m%d %T "

shopt -s histappend

case "$TERM" in
  xterm*|rxvt*|screen|tmux*)
    PS1='${debian_chroot:+($debian_chroot)}\[\033[30;1m\]\A \[\033[01;32m\]\[\033[00m\]${SSH_CONNECTION:+\[\033[32m\]\h}\[\033[01;34m\][\W]\[\033[00m\]\$ '
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    test "$TERM_PROGRAM" = "vscode" ||
      trap 'history -a;_h="$(HISTTIMEFORMAT= history 1)"; echo -ne "\x1b]0;$_h $(case "$_h" in *";"*) echo " ($BASH_COMMAND)";;esac)  ($USER@$HOSTNAME: $PWD)\x07"' DEBUG
    if type _add_status_to_ps1 >/dev/null 2>&1;then _add_status_to_ps1 ;fi
  ;;
esac

if [ -x /usr/bin/dircolors ]; then
  test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
  alias ls='ls --color=auto'

  alias grep='grep --color=auto'
  alias fgrep='fgrep --color=auto'
  alias egrep='egrep --color=auto'
fi

if [ -f ~/.bash_aliases ]; then
  . ~/.bash_aliases
fi

if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
  . /etc/bash_completion
fi

unset _IN_BASH_PROFILE
