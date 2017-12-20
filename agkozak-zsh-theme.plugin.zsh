#              _                 _
#   __ _  __ _| | _____ ______ _| | __
#  / _` |/ _` | |/ / _ \_  / _` | |/ /
# | (_| | (_| |   < (_) / / (_| |   <
#  \__,_|\__, |_|\_\___/___\__,_|_|\_\
#        |___/
#
# A dynamic color prompt for zsh with Git, vi mode, and exit status indicators
#
# Copyright (C) 2017 Alexandros Kozák
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
#
# https://github.com/agkozak/agkozak-zsh-theme
#

# shellcheck disable=SC2034,SC2088,SC2148,SC2154,SC2190

# $psvar[] Usage
#
# $psvar Index  Prompt String Equivalent    Usage
#
# $psvar[1]     %1v                         Hostname/abbreviated hostname (only
#                                           displayed for SSH connections)
# $psvar[2]     %2v                         Working directory or abbreviation
#                                           thereof
# $psvar[3]     %3v                         Current working Git branch, along
#                                           with indicator of changes made

setopt PROMPT_SUBST

###########################################################
# Is the user connected via SSH?
###########################################################
_agkozak_is_ssh() {
  if [[ -n $SSH_CONNECTION ]] || [[ -n $SSH_CLIENT ]] || [[ -n $SSH_TTY ]]; then
    true
  else
    case $EUID in
      0)
        case $(ps -o comm= -p $PPID) in
          sshd|*/sshd) true ;;
          *) false ;;
        esac
        ;;
      *) false ;;
    esac
  fi
}

###########################################################
# Does the terminal support enough colors?
###########################################################
_agkozak_has_colors() {
  (( $(tput colors) >= 8 ))
}

############################################################
# Emulation of bash's PROMPT_DIRTRIM for zsh
#
# In $PWD, substitute $HOME with ~; if the remainder of the
# $PWD has more than two directory elements to display,
# abbreviate it with '...', e.g.
#
#   $HOME/dotfiles/polyglot/img
#
# will be displayed as
#
#   ~/.../polyglot/img
#
# Arguments
#  $1 Number of directory elements to display
############################################################
_agkozak_prompt_dirtrim() {
  [[ $1 -ge 1 ]] || set 2
  local abbreviated_path
  case $PWD in
    $HOME*)
      abbreviated_path=$(print -Pn "%($(($1 + 2))~|~/.../%${1}~|%~)")
      ;;
    *)
      abbreviated_path=$(print -Pn "%($(($1 + 1))~|.../%${1}~|%~)")
      ;;
  esac
  print -n "$abbreviated_path"
}

###########################################################
# Display current branch name, followed by symbols
# representing changes to the working copy
###########################################################
_agkozak_branch_status() {
  local ref branch
  ref=$(git symbolic-ref --quiet HEAD 2> /dev/null)
  case $? in        # See what the exit code is.
    0) ;;           # $ref contains the name of a checked-out branch.
    128) return ;;  # No Git repository here.
    # Otherwise, see if HEAD is in detached state.
    *) ref=$(git rev-parse --short HEAD 2> /dev/null) || return ;;
  esac
  branch=${ref#refs/heads/}
  printf ' (%s%s)' "$branch" "$(_agkozak_branch_changes)"
}

###########################################################
# Display symbols representing changes to the working copy
###########################################################
_agkozak_branch_changes() {
  local git_status symbols k

  git_status=$(LC_ALL=C command git status 2>&1)

  declare -A messages

  messages=(
              'renamed:'                '>'
              'Your branch is ahead of' '*'
              'new file:'               '+'
              'Untracked files'         '?'
              'deleted'                 'x'
              'modified:'               '!'
           )

  for k in ${(@k)messages}; do
    case $git_status in
      *${k}*) symbols="${messages[$k]}${symbols}" ;;
    esac
  done

  [[ -n $symbols ]] && printf ' %s' "$symbols"
}

###########################################################
# Runs right before the prompt is displayed
#
# 1) Imitates bash's PROMPT_DIRTRIM behavior
# 2) Calculates working branch and working copy status
###########################################################
precmd() {
  psvar[2]=$(_agkozak_prompt_dirtrim "$AGKOZAK_PROMPT_DIRTRIM")
  psvar[3]=$(_agkozak_branch_status)
}

###########################################################
# When the user enters vi command mode, the % or # in the
# prompt changes into a colon
###########################################################
_agkozak_vi_mode_indicator() {
  case $KEYMAP in
    vicmd) print -n ':' ;;
    *) print -n '%#' ;;
  esac
}

###########################################################
# Redraw the prompt when the vi mode changes
###########################################################
zle-keymap-select() {
  zle reset-prompt
  zle -R
}

###########################################################
# Redraw prompt when terminal size changes
###########################################################
TRAPWINCH() {
  zle && zle -R
}

zle -N zle-keymap-select

# Only display the $HOSTNAME for an ssh connection
if _agkozak_is_ssh; then
  psvar[1]=$(print -Pn "@%m")
else
  psvar[1]=''
fi

if _agkozak_has_colors; then
  # Autoload zsh colors module if it hasn't been autoloaded already
  if ! whence -w colors > /dev/null 2>&1; then
    autoload -Uz colors
    colors
  fi

  PS1='%{$fg_bold[green]%}%n%1v%{$reset_color%} %{$fg_bold[blue]%}%2v%{$reset_color%}%{$fg[yellow]%}%3v%{$reset_color%} $(_agkozak_vi_mode_indicator) '

  # The right prompt will show the exit code if it is not zero.
  RPS1="%(?..%{$fg_bold[red]%}(%?%)%{$reset_color%})"
else
  PS1='%n%1v %2v%3v $(_agkozak_vi_mode_indicator) '
  RPS1="%(?..(%?%))"
fi

# Clean up environment
unset -f _agkozak_is_ssh _agkozak_has_colors

# vim: tabstop=2 expandtab:
