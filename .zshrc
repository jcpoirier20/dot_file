#!/bin/sh
source ~/.pvt_env_vars
source "$HOME/.cargo/env"
autoload -U compinit
compinit
source <(jj util completion zsh)

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
    lsof -ti :1337 | xargs kill
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

link_tecton_sdk(){
    local command="$1"
    
    # Validate that a command was provided
    if [[ -z "$command" ]]; then
        echo -e "${YELLOW} ❌ No command specified. Use sdklink or sdkunlink aliases. ${NC}"
        return 1
    fi
    
    # Validate command
    if [[ "$command" != "link" && "$command" != "unlink" ]]; then
        echo -e "${YELLOW} ❌ Invalid command: $command. Use 'link' or 'unlink'. ${NC}"
        return 1
    fi
    
    # Set up variables based on command
    local action_verb action_past_tense yarn_command
    if [[ "$command" == "link" ]]; then
        action_verb="Linking"
        action_past_tense="linked"
        yarn_command="yarn link q2-tecton-sdk"
    else
        action_verb="Unlinking"
        action_past_tense="unlinked"
        yarn_command="yarn unlink q2-tecton-sdk"
    fi
    
    echo -e "${GREEN}${CHECK_ICON} Starting SDK ${command}ing process... ${NC}"
    
    # Change to the SDK directory
    if ! pushd ~/code/sdk >/dev/null 2>&1; then
        echo -e "${YELLOW} ❌ Error: Could not find ~/code/sdk directory ${NC}"
        return 1
    fi
    
    # Set up trap to ensure we always return to original directory
    trap 'popd >/dev/null 2>&1; trap - INT' EXIT INT
    
    echo -e "${GREEN}${CHECK_ICON} Searching for projects with frontend folders... ${NC}"
    
    local processed_count=0
    
    # Iterate through all directories in the current location
    for dir in */; do
        # Remove trailing slash from directory name
        dir_name="${dir%/}"
        
        # Skip if not a directory
        if [[ ! -d "$dir_name" ]]; then
            continue
        fi
        
        # Check if this directory has a frontend folder
        if [[ -d "$dir_name/frontend" ]]; then
            echo -e "${YELLOW} Found frontend in: $dir_name ${NC}"
            
            # Check if frontend directory has a package.json file
            if [[ ! -f "$dir_name/frontend/package.json" ]]; then
                echo -e "${YELLOW}   ❌ No package.json found in $dir_name/frontend, skipping... ${NC}"
                continue
            fi
            
            # Change to the frontend directory and run yarn command
            if pushd "$dir_name/frontend" >/dev/null 2>&1; then
                echo -e "${GREEN}   ${action_verb} q2-tecton-sdk in $dir_name/frontend... ${NC}"
                
                if eval "$yarn_command" 2>/dev/null; then
                    echo -e "${GREEN}   ${CHECK_ICON} Successfully ${action_past_tense} q2-tecton-sdk ${NC}"
                    ((processed_count++))
                else
                    echo -e "${YELLOW}   ❌ Failed to ${command} q2-tecton-sdk in $dir_name/frontend ${NC}"
                fi
                
                # Return to the SDK root directory
                popd >/dev/null
            else
                echo -e "${YELLOW}   ❌ Could not access $dir_name/frontend directory ${NC}"
            fi
        fi
    done
    
    if [[ $processed_count -eq 0 ]]; then
        echo -e "${YELLOW} No projects with frontend folders found to ${command} ${NC}"
    else
        # Capitalize first letter of action_past_tense (zsh compatible)
        local capitalized_action="${(C)action_past_tense}"
        echo -e "${GREEN}${CHECK_ICON} SDK ${command}ing completed! ${capitalized_action} q2-tecton-sdk to $processed_count project(s) ${NC}"
    fi
}

# Link Tecton packages to NGAM and start Tecton local server in HTTPS
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

    pushd ~/code/ngam/packages/q2-uux >/dev/null
    yarn link q2-tecton-sdk
    echo -e "${GREEN}${CHECK_ICON} INFRA-CELLS UP! ${NC}"
    yarn link q2-tecton-platform
    echo -e "${GREEN}${CHECK_ICON} MEGA-THRUSTERS ARE A GO! ${NC}"
    popd >/dev/null

    cd ~/code/tecton
    # Check for SSL certificates and copy over if necessary
    if [[ ! -f "localhost.crt" ]] || [[ ! -f "localhost.key" ]]; then
        echo -e "${YELLOW} SSL certificates not found in $(pwd). Attempting to copy from home directory... ${NC}"
        if [[ -f ~/localhost.crt ]] && [[ -f ~/localhost.key ]]; then
            cp ~/localhost.{crt,key} .
            echo -e "${GREEN}${CHECK_ICON} SSL certificates copied successfully. ${NC}"
        else
            echo -e "${YELLOW} Warning: SSL certificates not found in home directory. HTTPS may not work correctly. ${NC}"
        fi
    fi
    echo -e "${GREEN}${CHECK_ICON} LET'S GO VOLTRON FORCE! ${NC}"
    yarn build:local:https
}

# Unlink Tecton packages from NGAM and reinstall base dependencies
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
    pushd ~/code/ngam/packages/q2-uux >/dev/null
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
        # If we found a master process, ask if user wants to reload
        echo "${YELLOW} Nginx is already running. Reload nginx config? (y/N): ${NC}"
        read -r reload_choice
        # Default to 'N' if no input provided
        reload_choice=${reload_choice:-N}
        if [[ "$reload_choice" =~ ^[Yy]$ ]]; then
            echo "${YELLOW} Enter password to reload nginx config... ${NC}"
            sudo nginx -s reload
            echo "${GREEN}${CHECK_ICON} Nginx config reloaded. ${NC}"
        else
            echo "${GREEN}${CHECK_ICON} Skipping nginx reload. ${NC}"
        fi
    fi
    echo "${GREEN}${CHECK_ICON} Starting the NGAM local server... ${NC}"
    yarn start
}

link_antilles() {
    cd ~/code/sdk
    ssdk
    pip install -U -e ~/code/antilles/sdk
     # Check if q2-sdk is installed and where it's installed from
    local q2_sdk_info=$(pip show q2-sdk 2>/dev/null)
    
    if [[ -z "$q2_sdk_info" ]]; then
        echo "${YELLOW} ❌ q2-sdk is not installed in the repo. Be sure you ran 'pip install -r requirements.txt' ${NC}"
        return 1
    fi
    
    # Extract the location from pip show output
    local editable_project=$(echo "$q2_sdk_info" | grep "Editable project location:" | cut -d' ' -f4)
    
    if [[ -n "$editable_project" ]]; then
        # Check if it points to our local antilles/sdk
        if [[ "$editable_project" == *"/code/antilles/sdk"* ]]; then
            echo "${GREEN}${CHECK_ICON} Antilles is correctly linked for local SDK development! ${NC}"
        else
            echo "${YELLOW} ❌ Unexpected location for local Antilles repo: $editable_project ${NC}"
            echo "${YELLOW}   Expected: */code/antilles/sdk ${NC}"
            return 1
        fi
    else
        echo "${YELLOW} ❌ Antilles is not linked for local development ${NC}"
        return 1
    fi
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

get_remote_branches() {
    git fetch --prune
    # Get the list of remote branches and their authors
    git for-each-ref --format="%(authorname) %(refname:short)" refs/remotes/origin | \
    awk '{
        author = "";
        branch = $NF;
        for (i=1; i<NF; i++) {
        if (i>1) author = author " ";
        author = author $i;
        }
        
        # Filter out unwanted branches
        if (branch !~ /^origin\/(FRB_release|release|HEAD|develop|master)/) {
        # Remove the "origin/" prefix
        branch = substr(branch, 8);
        authors[author]++;
        if (branches[author] == "") {
            branches[author] = branch;
        } else {
            branches[author] = branches[author] ", " branch;
        }
        }
    }
    END {
        for (author in authors)
        print authors[author] "###" author "###" branches[author];
    }' | \
    sort -nr | \
    sed "s/\(^[0-9]*\)###\(.*\)###\(.*\)/\x1b[1;32m\1\x1b[0m \x1b[36m\2\x1b[0m \x1b[33m\3\x1b[0m/"
}

remove_branches() {
    # Check if at least one branch name is provided
    if [ -z "$1" ]; then
    echo "Usage: $0 <comma-delimited-branch-names>"
    exit 1
    fi

    # Convert the comma-delimited list to an array
    IFS=',' read -ra BRANCHES <<< "$1"

    # Loop through each branch and delete it from the remote
    for branch in "${BRANCHES[@]}"; do
    branch=$(echo "$branch" | xargs)  # Trim any leading/trailing whitespace
    echo "Removing branch '$branch' from remote..."
    git push origin --delete "$branch"
    done

    echo "Done."
}

# Linearize by rebasing all descendants of a parent commit in chronological order (jj only)
jjlinearize() {
    if [ $# -eq 0 ]; then
        echo "Usage: jj_linearize <parent-change-id>"
        echo "Example: jj_linearize nowzuvwo"
        return 1
    fi

    PARENT_CHANGE_ID="$1"

    echo "Linearizing descendants of: $PARENT_CHANGE_ID"

    # Get ALL descendants - use default format then extract change IDs
    DESCENDANTS_OUTPUT=$(jj log -r "descendants($PARENT_CHANGE_ID) & ~$PARENT_CHANGE_ID" --reversed --no-graph)
    
    # Extract change IDs from the output (they're at the beginning of each line)
    CHILDREN_ARRAY=($(echo "$DESCENDANTS_OUTPUT" | grep -o '^[a-z0-9]\{8\}' | head -20))

    if [ ${#CHILDREN_ARRAY[@]} -eq 0 ]; then
        echo "No descendants found for change: $PARENT_CHANGE_ID"
        return 0
    fi

    # Show what we found
    echo "Found ${#CHILDREN_ARRAY[@]} descendants:"
    for change_id in "${CHILDREN_ARRAY[@]}"; do
        if [ -n "$change_id" ]; then
            desc=$(jj log -r "$change_id" --no-graph -T 'description.first_line()')
            echo "✏️ $change_id: $desc"
        fi
    done

    # If only one descendant, nothing to linearize
    if [ ${#CHILDREN_ARRAY[@]} -eq 1 ]; then
        echo "Only one descendant found - nothing to linearize"
        return 0
    fi

    # Rebase the first descendant to the parent
    FIRST_CHANGE_ID="${CHILDREN_ARRAY[1]}"
    jj rebase -s "$FIRST_CHANGE_ID" -d "$PARENT_CHANGE_ID"
    PREVIOUS_CHANGE_ID="$FIRST_CHANGE_ID"

    # Rebase each subsequent descendant to the previous one
    for i in $(seq 2 ${#CHILDREN_ARRAY[@]}); do
        CURRENT_CHANGE_ID="${CHILDREN_ARRAY[$i]}"
        jj rebase -s "$CURRENT_CHANGE_ID" -d "$PREVIOUS_CHANGE_ID"
        PREVIOUS_CHANGE_ID="$CURRENT_CHANGE_ID"
    done

    echo "Linearization complete! Final order:"
    jj log -r "$PARENT_CHANGE_ID::" --limit 10
}

watchlog() {
    hwatch --color jj --ignore-working-copy log --color=always
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
alias ong='cd ~/code/ngam && code .'

# starts the nginx server and builds ngam
alias snginx="nginx_smart_start"

# opens the nginx conf file for editing
alias enginx="code /opt/homebrew/etc/nginx/nginx.conf"


##### ANTILLES/SDK #####
# navigate to Antilles root
alias cdant="cd ~/code/antilles && sant"

# opens Antilles repo in VSCode
alias oant="cd ~/code/antilles && code ."

# navigate to SDK root
alias cdsdk="cd ~/code/sdk && ssdk"

# opens SDK repo in VSCode
alias osdk="cd ~/code/sdk && code ."

# runs the necessary scripts to start the SDK environment inside sdk repos
alias ssdk="source ~/.antilles/sdk_env_vars.sh && source ~/.antilles/antilles_completion.zsh && source .env/bin/activate"

# runs the necessary scripts to start the Antilles environment inside antilles repos
alias sant="source ~/.antilles/sdk_env_vars.sh && source ~/.antilles/antilles_completion.zsh && source ~/code/antilles/.venv/bin/activate"


# link q2-tecton-sdk to all frontend projects in SDK directory
alias sdklink="link_tecton_sdk link"

# unlink q2-tecton-sdk from all frontend projects in SDK directory
alias sdkunlink="link_tecton_sdk unlink"

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