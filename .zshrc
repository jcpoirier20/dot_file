#!/bin/sh

source ~/.antilles/sdk_env_vars.sh
source ~/.pvt_env_vars
source ~/.nvm/nvm.sh

# sets VSCode as editor
export EDITOR="code --wait --new-window"

##### HELPERS #####
killPort() {
    lsof -ti:$1 | xargs kill
}

parse_git_branch() {
    git branch 2> /dev/null | sed -n -e 's/^\* \(.*\)/\1/p'
}

set_upstream() {
    local current_branch=$(parse_git_branch)
    git push --set-upstream origin $current_branch
}

pull_origin() {
    local current_branch=$(parse_git_branch)
    git pull origin $current_branch
}

# NVM auto-switching
autoload -U add-zsh-hook
load_nvmrc() {
  local node_version="$(nvm version)"
  local nvmrc_path="$(nvm_find_nvmrc)"

  if [ -n "$nvmrc_path" ]; then
    local nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")

    if [ "$nvmrc_node_version" = "N/A" ]; then
      nvm install
    elif [ "$nvmrc_node_version" != "$node_version" ]; then
      nvm use
    fi
  elif [ "$node_version" != "$(nvm version default)" ]; then
    echo "Reverting to nvm default version"
    nvm use default
  fi
}

##### GIT SHORTCUTS #####
# create new branch
alias gcb="git checkout -b $1"

# switch branches
alias gc="git checkout $1"

# amend no edit commits
alias gca="git commit --amend --no-edit"

# pushes upstream origin with current branch name
alias gpu="set_upstream"

# force pushe changes
alias gpf="git push -f"

# pull origin
alias gpo="pull_origin"

# reset back one commit
alias grs="git reset --soft HEAD~1"


##### OPEN REPOS IN VSCODE #####
# opens Tecton in VSCode
alias otct="cd ~/code/tecton && code ."

# opens NGAM in VSCode
alias ongam='cd ~/code/ngam && code .'

# opens Tecton-Canary in VSCode
alias ocnry="cd ~/code/tecton-canary && code ."

# opens Antilles repo in VSCode
alias oant="cd ~/code/antilles && code ."

# opens SDK repo in VSCode
alias osdk="cd ~/code/sdk && code ."


##### LOCAL DEVELOPMENT #####
# builds the Tecton dev server
alias ybd="cd ~/code/tecton && yarn build:dev"

# spins up a local dev server of Tecton
alias ybl="cd ~/code/tecton && yarn build:local"

# spins up a local dev server of our documentation site
alias sdocs="cd ~/code/tecton/packages/docs && yarn clean && yarn start"

# runs linter on tecton packages
alias format="cd ~/code/tecton && yarn lint:fix"

# spins up a testing server for Tecton elements
alias stests="cd ~/code/tecton/packages/q2-tecton-elements && yarn test:dev"

# runs the necessary scripts to start the SDK environment inside sdk folder
alias ssdk="source ~/.antilles/sdk_env_vars.sh && source ~/.antilles/antilles_completion.zsh && source .env/bin/activate"

# runs the review-buddy tool
alias rb="cd ~/code/review-buddy && cargo run $1"

# opens the nginx conf file to point to different stacks
alias enginx="code /usr/local/etc/nginx/nginx.conf"

# navigate to tecton root
alias cdt="cd ~/code/tecton"

# navigate to ngam root
alias cdng="cd ~/code/ngam"

# navigate to tecton-canary root
alias cdcn="cd ~/code/tecton-canary"

# navigate to sdk root
alias cdsdk="cd ~/code/sdk"


##### OTHER #####
# edit zshrc file
alias ezsh="code ~/.zshrc"

# source zshrc file
alias szsh="source ~/.zshrc"

# push zsh file updates to chezmoi
alias uzsh="chezmoi add ~/.zshrc && chezmoi git -- add dot_zshrc && chezmoi git -- commit -m 'Updated zsh dotfile' && chezmoi git -- push && echo 'dotfiles repo update complete'"

# This loads nvm bash_completion
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

add-zsh-hook chpwd load_nvmrc
load_nvmrc
