# Dotfiles managed aliases

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Listing
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Safety nets
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Git shortcuts (when not using git aliases)
alias g='git'
alias gs='git status'
alias gd='git diff'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'

# Utility
alias h='history'
alias j='jobs -l'
alias path='echo -e ${PATH//:/\\n}'
alias ports='netstat -tulanp'
