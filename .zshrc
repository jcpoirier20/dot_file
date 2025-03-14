#!/bin/sh
source ~/.pvt_env_vars

export PATH="/Users/jpoirier/bin:$PATH"
export EDITOR="code --wait --new-window"
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
export NVM_DIR="$HOME/.nvm"
CHECK_ICON="\xE2\x9C\x94"
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

autoload -U add-zsh-hook


##### PYTHON HELPERS ##### 
for cmd in pyenv python python3 pip pip3; do
    eval "function $cmd() {
        unset -f pyenv python pip python3 pip3
        eval \"\$(command pyenv init -)\"
        $cmd \"\$@\"
    }"
done

# Check for .python-version files
load_pyenv() {
    local dir="$(pwd -P)"
    
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/.python-version" ]]; then
            unset -f pyenv python pip python3 pip3
            eval "$(command pyenv init -)"
            return
        fi
        dir="$(dirname "$dir")"
    done
}


##### HELPERS #####

# Enable SSH tunnel to JB
enable_tunnel() {
    ssh -D 1337 -f -q -N jb
    echo "${GREEN}${CHECK_ICON} Tunnel Enabled on port 1337 ${NC}"
}
# Disable SSH tunnel to JB
disable_tunnel() {
    lsof -i :1337 | grep -o '\d+' | head -1 | xargs kill
    echo 'Tunnel Ended'
}

parse_git_branch() {
    git branch 2> /dev/null | sed -n -e 's/^\* \(.*\)/\1/p'
}

gpu() {
   local current_branch=$(parse_git_branch)
   
   if [[ $current_branch =~ ^[a-z]+/[A-Z]+-[0-9]+$ ]] ||
      [[ $current_branch =~ ^release/[0-9]+\.[0-9]+\.?[0-9]*[x]?$ ]]; then
       git push --set-upstream origin $current_branch
   else
       echo "Warning: Branch '$current_branch' doesn't match standard patterns."
       echo "Manually push with git push --set-upstream origin $current_branch"
   fi
}

gpo() {
    local current_branch=$(parse_git_branch)
    git pull origin $current_branch
}

apply_styleguide() {
    local file="$1"
    
    # If no argument provided, run the original command
    if [[ -z "$file" ]]; then
        pushd ~/code/tecton/packages/q2-tecton-elements >/dev/null
        trap 'popd >/dev/null; trap - INT' EXIT INT
        yarn style:fix
        return
    fi
    
    # Validate filename pattern
    if [[ ! "$file" =~ ^q2-.+\.tsx$ ]]; then
        echo "Error: Filename must start with 'q2-' and end with '.tsx'"
        return 1
    fi
    
    # Extract filename without extension
    local basename="${file%.tsx}"
    
    pushd ~/code/tecton/packages/q2-tecton-elements >/dev/null
    trap 'popd >/dev/null; trap - INT' EXIT INT
    yarn style:fix --path "src/components/${basename}/${file}"
}

# starts the Tecton test suite
stests() {
    pushd ~/code/tecton/packages/q2-tecton-elements >/dev/null
    trap 'popd >/dev/null; trap - INT' EXIT INT
    if [[ "$1" == "-v" ]]; then
        yarn test:dev
    else
        yarn test:dev --silent
    fi
}

# starts the Tecton docs server
sdocs() {
    pushd ~/code/tecton/packages/docs >/dev/null
    trap 'popd >/dev/null; trap - INT' EXIT INT
    yarn clean
    yarn start
}

update_dot_file() {
    pushd ~/code/dot_file/ >/dev/null
    trap 'popd >/dev/null; trap - INT' EXIT INT
    cp ~/.zshrc ~/code/dot_file/
    git add .
    git commit -m 'updated zshrc'
    git push
    source ~/.zshrc
    echo -e "${GREEN}${CHECK_ICON} dot_file repo updated ${NC}"
}

# Link Tecton packages to NGAM
voltron() {
    pushd ~/code/tecton/packages/q2-tecton-sdk >/dev/null
    trap 'popd >/dev/null 2>&1; cd ~/code/tecton; trap - INT' EXIT INT
    echo -e "${GREEN}${CHECK_ICON} READY TO FORM VOLTRON! ${NC}"
    yarn link
    popd >/dev/null
    echo -e "${GREEN}${CHECK_ICON} ACTIVATE INTERLOCKS! ${NC}"

    pushd ~/code/tecton/packages/q2-tecton-platform >/dev/null
    yarn link
    popd >/dev/null
    echo -e "${GREEN}${CHECK_ICON} DYNATHERMS CONNECTED! ${NC}"

    pushd ~/code/ngam >/dev/null
    yarn link q2-tecton-sdk
    echo -e "${GREEN}${CHECK_ICON} INFRA-CELLS UP! ${NC}"
    yarn link q2-tecton-platform
    echo -e "${GREEN}${CHECK_ICON} MEGA-THRUSTERS ARE A GO! ${NC}"
    popd >/dev/null

    cd ~/code/tecton
    echo -e "${GREEN}${CHECK_ICON} LET'S GO VOLTRON FORCE! ${NC}"
    yarn build:local:https
}

# Unlink Tecton packages from NGAM
unlink() {
    pushd ~/code/tecton/packages/q2-tecton-sdk >/dev/null
    trap 'popd >/dev/null 2>&1; cd ~/code/tecton; trap - INT' EXIT INT
    # Unlink Tecton packages
    yarn unlink
    popd >/dev/null
    pushd ~/code/tecton/packages/q2-tecton-platform >/dev/null
    yarn unlink
    popd >/dev/null
    # Unlink in NGAM and reinstall dependencies
    pushd ~/code/ngam >/dev/null
    yarn unlink q2-tecton-sdk
    yarn unlink q2-tecton-platform
    echo -e "${GREEN} Clean Installing NGAM dependencies... ${NC}"
    yarn nom
    yarn install
}

safe-rm() {
    if ! command -v trash &> /dev/null; then
    echo "Warning: 'trash' command not found. Please install it with 'brew install trash'"
    exit 1
    fi
    # Extract all arguments that aren't flags (starting with -)
    local files=()
    for arg in "$@"; do
        if [[ ! "$arg" =~ ^- ]]; then
            files+=("$arg")
        fi
    done
    
    # If we have files to delete, use trash command
    if (( ${#files[@]} > 0 )); then
        echo "🗑️  Sending to Trash instead of permanent deletion"
        trash "${files[@]}"
    else
        # No files specified, show trash usage
        command trash --help
    fi
}

nginx_smart_start() {
    cd ~/code/ngam
    # Use ps to search for nginx master process and capture the output
    # grep -v 'grep' excludes the grep process itself from results
    nginx_process=$(ps aux | grep "nginx: master" | grep -v grep)

    if [ -z "$nginx_process" ]; then
        # If the $nginx_process string is empty (no nginx master found)
        echo "${YELLOW} Nginx is not running. Starting Nginx... ${NC}"
        sudo nginx
        echo "${GREEN}${CHECK_ICON} Nginx is now running. ${NC}"
    else
        # If we found a master process, reload the configuration
        echo "${YELLOW} Nginx is already running. Reloading configuration... ${NC}"
        sudo nginx -s reload
        echo "${GREEN}${CHECK_ICON} Nginx configuration has reloaded. Starting Nginx... ${NC}"
    fi

    yarn start
}

load_nvmrc() {
    local dir="$(pwd -P)"
    
    # look for nvmrc file going up directories until root
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/.nvmrc" ]]; then
            # Load nvm if it hasn't been loaded yet
            if ! type nvm >/dev/null 2>&1; then
                [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
            fi
            
            local node_version="$(nvm version | sed 's/^v//')"  # Strip the "v"
            local node_major_version="${node_version%%.*}"  # Extract the major version
            local nvmrc_node_version=$(cat "$dir/.nvmrc" | sed 's/^v//')  # Read the .nvmrc file and strip the "v"
            local nvmrc_node_major_version="${nvmrc_node_version%%.*}"  # Extract the major version
            if [ "$nvmrc_node_version" = "N/A" ]; then
                nvm install
            elif [ "$nvmrc_node_major_version" != "$node_major_version" ]; then
                echo "Switching to Node.js version $nvmrc_node_version"
                nvm use "$nvmrc_node_version"
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

# force push changes
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

# runs linter on tecton packages
alias format="cd ~/code/tecton && yarn lint:fix"

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

# runs the necessary scripts to start the Antilles environment inside antilles repos
alias sant="source ~/.antilles/sdk_env_vars.sh && source ~/.antilles/antilles_completion.zsh && source ~/code/antilles/.venv/bin/activate"

# runs the review-buddy tool
alias rb="cd ~/code/review-buddy && cargo run $1"


##### OTHER #####
# intercept rm commands to use trash from homebrew
alias rm="safe-rm"
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
load_nvmrc
add-zsh-hook chpwd load_pyenv
load_pyenv