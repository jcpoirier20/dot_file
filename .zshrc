#!/bin/sh

source ~/.antilles/sdk_env_vars.sh
source ~/.pvt_env_vars
eval "$(pyenv init -)"

export PATH="/Users/jpoirier/bin:$PATH"
export EDITOR="code --wait --new-window"
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
export NVM_DIR="$HOME/.nvm"

##### HELPERS #####
killport() {
    lsof -ti:$1 | xargs kill
}

enable_tunnel() {
    ssh -D 1337 -f -q -N jb
    echo 'Tunnel Enabled on port 1337'
}

disable_tunnel() {
    lsof -i :1337 | grep -o '\d+' | head -1 | xargs kill
    echo 'Tunnel Ended'
}

parse_git_branch() {
    git branch 2> /dev/null | sed -n -e 's/^\* \(.*\)/\1/p'
}

gpu() {
    local current_branch=$(parse_git_branch)
    git push --set-upstream origin $current_branch
}

gpo() {
    local current_branch=$(parse_git_branch)
    git pull origin $current_branch
}

apply_styleguide() {
    pushd ~/code/tecton/packages/q2-tecton-elements >/dev/null
    yarn style:fix
    popd >/dev/null
}

update_dot_file() {
    pushd ~/code/dot_file/ >/dev/null
    cp ~/.zshrc ~/code/dot_file/
    git add .
    git commit -m 'updated zshrc'
    git push
    popd >/dev/null
    source ~/.zshrc
    echo -e "\033[0;32m dot_file repo updated \033[0m"
}

# Link Tecton packages to NGAM
voltron() {
    echo -e "\033[0;32m READY TO FORM VOLTRON! \033[0m"
    pushd ~/code/tecton/packages/q2-tecton-sdk >/dev/null
    yarn link
    popd >/dev/null
    echo -e "\033[0;32m ACTIVATE INTERLOCKS! \033[0m"

    pushd ~/code/tecton/packages/q2-tecton-platform >/dev/null
    yarn link
    popd >/dev/null
    echo -e "\033[0;32m DYNATHERMS CONNECTED! \033[0m"

    pushd ~/code/ngam >/dev/null
    yarn link q2-tecton-sdk
    echo -e "\033[0;32m INFRA-CELLS UP! \033[0m"
    yarn link q2-tecton-platform
    echo -e "\033[0;32m MEGA-THRUSTERS ARE A GO! \033[0m"
    popd >/dev/null

    pushd ~/code/tecton >/dev/null
    echo -e "\033[0;32m LET'S GO VOLTRON FORCE! \033[0m"
    yarn build:local:https
}

# Unlink Tecton packages from NGAM
unlink() {
    # Unlink Tecton packages
    pushd ~/code/tecton/packages/q2-tecton-sdk >/dev/null
    yarn unlink
    popd >/dev/null
    pushd ~/code/tecton/packages/q2-tecton-platform >/dev/null
    yarn unlink
    popd >/dev/null
    # Unlink in NGAM and reinstall dependencies
    pushd ~/code/ngam >/dev/null
    yarn unlink q2-tecton-sdk
    yarn unlink q2-tecton-platform
    echo -e "\033[0;32m Clean Installing NGAM dependencies... \033[0m"
    yarn nom
    yarn install
    popd >/dev/null
    cd ~/code/tecton
}

nginx_smart_start() {
    cd ~/code/ngam
    # Use ps to search for nginx master process and capture the output
    # grep -v 'grep' excludes the grep process itself from results
    nginx_process=$(ps aux | grep "nginx: master" | grep -v grep)

    if [ -z "$nginx_process" ]; then
        # If the $nginx_process string is empty (no nginx master found)
        echo "Nginx is not running. Starting Nginx..."
        sudo nginx
        echo "\033[0;32m Nginx is now running. \033[0m"
    else
        # If we found a master process, reload the configuration
        echo "Nginx is already running. Reloading configuration..."
        sudo nginx -s reload
        echo "\033[0;32m Nginx configuration has reloaded. Starting Nginx... \033[0m"
    fi

    yarn start
}

autoload -U add-zsh-hook
load_nvmrc() {
    local dir="$(pwd -P)"
    
    # Keep going up directories until we hit root
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/.nvmrc" ]]; then
            # Load nvm if it hasn't been loaded yet
            if ! type nvm >/dev/null 2>&1; then
                [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
            fi
            
            local node_version="$(nvm version)"
            local nvmrc_node_version=$(nvm version "$(cat "$dir/.nvmrc")")

            if [ "$nvmrc_node_version" = "N/A" ]; then
                nvm install
            elif [ "$nvmrc_node_version" != "$node_version" ]; then
                nvm use
            fi
            return
        fi
        dir="$(dirname "$dir")"
    done
}

##### GIT SHORTCUTS #####
# create new branch
alias gcb="git checkout -b $1"

# switch branches
alias gc="git checkout $1"

# amend no edit commits
alias gca="git commit --amend --no-edit"

# force pushe changes
alias gpf="git push -f"

# reset back one commit
alias grs="git reset --soft HEAD~1"


##### TECTON #####
# navigate to tecton root
alias cdt="cd ~/code/tecton"

# opens Tecton in VSCode
alias otct="cd ~/code/tecton && code ."

# builds the Tecton packages
alias ybd="cd ~/code/tecton && yarn build:dev"

# starts a local dev server of Tecton packages
alias ybl="cd ~/code/tecton && yarn build:local"

# starts a local dev server of Tecton packages in HTTPS
alias yblh="cd ~/code/tecton && yarn build:local:https"

# starts a local dev server of the documentation site
alias sdocs="cd ~/code/tecton/packages/docs && yarn clean && yarn start"

# runs linter on tecton packages
alias format="cd ~/code/tecton && yarn lint:fix"

# starts a testing server for Tecton elements
alias stests="cd ~/code/tecton/packages/q2-tecton-elements && yarn test:dev"

alias styleguide="apply_styleguide"

# navigate to tecton-canary root
alias cdcn="cd ~/code/tecton-canary"

# opens Tecton-Canary in VSCode
alias ocnry="cd ~/code/tecton-canary && code ."


##### NGAM #####
# navigate to ngam root
alias cdng="cd ~/code/ngam"

# opens NGAM in VSCode
alias ongam='cd ~/code/ngam && code .'

# starts the nginx server and builds ngam
alias snginx="nginx_smart_start"

# opens the nginx conf file for editing
alias enginx="code /opt/homebrew/etc/nginx/nginx.conf"


##### ANTILLES/SDK #####
# navigate to Antilles root
alias cdant="cd ~/code/antilles"

# opens Antilles repo in VSCode
alias oant="cd ~/code/antilles && code ."

# navigate to SDK root
alias cdsdk="cd ~/code/sdk"

# opens SDK repo in VSCode
alias osdk="cd ~/code/sdk && code ."

# runs the necessary scripts to start the SDK environment inside sdk repos
alias ssdk="source ~/.antilles/sdk_env_vars.sh && source ~/.antilles/antilles_completion.zsh && source .env/bin/activate"

# runs the review-buddy tool
alias rb="cd ~/code/review-buddy && cargo run $1"


##### OTHER #####
# move to DPPython project
alias cddp="cd ~/code/personal/DPPython"

# load main.py into wokwi simulator
alias wokwi="python -m mpremote connect port:rfc2217://localhost:4000 run main.py"

# edit zshrc file
alias ezsh="code ~/.zshrc"

# edit pvt_env_vars file
alias epvt="code ~/.pvt_env_vars"

# source zshrc file
alias szsh="source ~/.zshrc"

# copy edits to dot_file repo and push
alias uzsh="update_dot_file"

# Run when changing directories
add-zsh-hook chpwd load_nvmrc

# Run on initial shell start if we're in a directory with .nvmrc
load_nvmrc