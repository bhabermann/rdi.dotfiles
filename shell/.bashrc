# Dotfiles managed shell customizations

# Source bash aliases if file exists
if [ -f ~/.bash_aliases ]; then
  source ~/.bash_aliases
fi

# Enable color support
if [ -x /usr/bin/dircolors ]; then
  test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
fi

# History settings
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoreboth:erasedups
shopt -s histappend

# Better tab completion
bind 'set completion-ignore-case on'
bind 'set show-all-if-ambiguous on'
