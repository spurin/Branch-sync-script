#!/bin/bash

# Initialize Variables
YOUR_USER=""
AUTO_PUSH=false
FUTURE_RELEASE=""
REPO_NAME="website"  # Default repository name

# Colors
COLOR_BLUE="\033[1;34m"
COLOR_GREEN="\033[1;32m"
COLOR_YELLOW="\033[1;33m"
COLOR_PURPLE="\033[1;35m"
COLOR_RED="\033[1;31m"
COLOR_RESET="\033[0m"

# Helper Function to print in color
print_color() {
  echo -e "${1}${2}${COLOR_RESET}"
}

# Helper Function to print heading in color
print_heading() {
  echo -e "\n${1}${2}${COLOR_RESET}"
}

# Help Function
help() {
  print_color "$COLOR_BLUE" "Usage: $0 FUTURE_RELEASE [-p | --push] [-u | --user] [-r | --repo REPO_NAME]"
  print_color "$COLOR_BLUE" "Options:"
  print_color "$COLOR_BLUE" "  -p, --push    Push the branch sync automatically without prompting"
  print_color "$COLOR_BLUE" "  -u, --user    Manually set GitHub user"
  print_color "$COLOR_BLUE" "  -r, --repo    Set GitHub repository name (default is 'website')"
  print_color "$COLOR_BLUE" "  -h, --help    Display this help message"
}

# Print command with description
print_command() {
  print_color "$COLOR_BLUE" "Executing: $1"
}

# Execute command and handle errors
execute() {
  print_command "$1"
  eval "$1"
  if [ $? -ne 0 ]; then
    print_color "$COLOR_RED" "Error: Command failed - $1"
    exit 1
  fi
}

# Prompt for confirmation on the same line
prompt_confirmation() {
  local message=$1
  echo -en "${COLOR_PURPLE}${message} (y/n): ${COLOR_RESET}"
  read -r response
  [[ "$response" =~ ^[Yy]$ ]]
}

# Parse command-line options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) help; exit 0 ;;
    -p|--push) AUTO_PUSH=true; shift ;;
    -u|--user) YOUR_USER="$2"; shift 2 ;;
    -r|--repo) REPO_NAME="$2"; shift 2 ;;
    *) FUTURE_RELEASE="$1"; shift ;;
  esac
done

# Validation
if [ -z "$FUTURE_RELEASE" ]; then
  help; exit 1
fi

if [ -z "$YOUR_USER" ]; then
  print_color "$COLOR_RED" "Error: Please provide your GitHub user with the -u option."
  help
  exit 1
fi

# Configuration Display
print_color "$COLOR_BLUE" "USER: $YOUR_USER"
print_color "$COLOR_BLUE" "FUTURE_RELEASE: $FUTURE_RELEASE"
print_color "$COLOR_BLUE" "REPO_NAME: $REPO_NAME"
print_color "$COLOR_BLUE" "AUTO_PUSH: $AUTO_PUSH"

# Proceed Confirmation
if ! prompt_confirmation "Do you want to proceed with these values?"; then
  print_color "$COLOR_RED" "Terminating..."
  exit 1
fi

# Git Operations
initialize_local_fork() {
  print_heading $COLOR_PURPLE "Initializing local repository: Checking for existing fork of '${REPO_NAME}' or cloning a new one:"
  if [ -d "$REPO_NAME" ]; then
    cd "$REPO_NAME" || exit
    remote_url=$(git config --get remote.origin.url)

    if [ "$remote_url" == "git@github.com:$YOUR_USER/$REPO_NAME.git" ]; then
      print_color "$COLOR_GREEN" "Local repository '${REPO_NAME}' is correctly configured as a fork of your GitHub repository."
    else
      print_color "$COLOR_RED" "Directory '$REPO_NAME' exists but does not match your forked repository. Please check or delete the directory."
      exit 1
    fi
  else
    print_color "$COLOR_GREEN" "Cloning your GitHub fork of kubernetes/website to $REPO_NAME to set up a local copy."
    execute "git clone git@github.com:$YOUR_USER/$REPO_NAME.git"
    cd "$REPO_NAME" || exit
  fi
}

configure_upstream_remote() {
  print_heading $COLOR_PURPLE "Configuring upstream: Setting up official kubernetes/website repository as 'upstream':"
  if git remote get-url upstream &> /dev/null; then
    print_color "$COLOR_GREEN" "Upstream remote 'kubernetes/website' already configured."
  else
    print_color "$COLOR_GREEN" "Adding 'upstream' remote to connect with the official kubernetes/website repository."
    execute "git remote add upstream https://github.com/kubernetes/website.git"
  fi

  print_heading $COLOR_PURPLE "Setting upstream push URL to 'no_push' for safety:"
  push_url=$(git remote get-url --push upstream)
  if [ "$push_url" != "no_push" ]; then
    print_color "$COLOR_GREEN" "Updating push URL for upstream to 'no_push' to prevent accidental pushes."
    execute "git remote set-url --push upstream no_push"
  else
    print_color "$COLOR_GREEN" "Push URL for upstream is correctly set to 'no_push'."
  fi
}

update_local_branches_from_upstream() {
  print_heading $COLOR_PURPLE "Synchronizing with upstream branches: Fetching 'main' and 'dev-$FUTURE_RELEASE' from upstream:"
  print_color "$COLOR_GREEN" "Fetching the latest 'main' branch from the upstream repository."
  execute "git fetch upstream main"
  print_color "$COLOR_GREEN" "Fetching 'dev-$FUTURE_RELEASE' branch from upstream."
  execute "git fetch upstream dev-$FUTURE_RELEASE"
}

prepare_release_branch() {
  print_heading $COLOR_PURPLE "Setting up local tracking for 'dev-$FUTURE_RELEASE' branch:"
  if git show-ref --verify --quiet refs/heads/dev-$FUTURE_RELEASE; then
    print_color "$COLOR_GREEN" "Switching to existing local branch 'dev-$FUTURE_RELEASE'."
    execute "git checkout dev-$FUTURE_RELEASE"
    if ! git rev-parse --abbrev-ref --symbolic-full-name dev-$FUTURE_RELEASE@{u} &>/dev/null; then
      print_color "$COLOR_GREEN" "Setting tracking for local branch 'dev-$FUTURE_RELEASE' to track 'upstream/dev-$FUTURE_RELEASE'."
      execute "git branch --set-upstream-to=upstream/dev-$FUTURE_RELEASE dev-$FUTURE_RELEASE"
    else
      print_color "$COLOR_GREEN" "Tracking already exists for local branch 'dev-$FUTURE_RELEASE' to track 'upstream/dev-$FUTURE_RELEASE'."
    fi
  else
    print_color "$COLOR_GREEN" "Creating and setting up local 'dev-$FUTURE_RELEASE' to track 'upstream/dev-$FUTURE_RELEASE'."
    execute "git checkout --track upstream/dev-$FUTURE_RELEASE"
  fi
}

sync_release_branch_with_main() {
  print_heading $COLOR_PURPLE "Synchronizing 'dev-$FUTURE_RELEASE' with upstream and merging with 'main':"
  print_color "$COLOR_GREEN" "Pulling the latest changes with fast-forward only to update 'dev-$FUTURE_RELEASE'."
  execute "git pull --ff-only"
  print_color "$COLOR_GREEN" "Merging 'upstream/main' into 'dev-$FUTURE_RELEASE' to stay current with upstream changes."
  if ! execute "git merge upstream/main -m 'Merge main into dev-$FUTURE_RELEASE to keep up-to-date'"; then
    print_color "$COLOR_RED" "Error: Merge conflict detected. Resolve conflicts before proceeding."
    exit 1
  fi
}

manage_merged_release_branch() {
  print_heading $COLOR_PURPLE "Creating or updating 'merged-main-dev-$FUTURE_RELEASE' to combine 'main' with 'dev-$FUTURE_RELEASE':"
  print_color "$COLOR_GREEN" "Fetching latest branches from your fork of the repository."
  execute "git fetch -v origin"
  
  if git show-ref --verify --quiet refs/heads/merged-main-dev-$FUTURE_RELEASE; then
    print_color "$COLOR_GREEN" "Switching to existing branch 'merged-main-dev-$FUTURE_RELEASE'."
    execute "git switch merged-main-dev-$FUTURE_RELEASE"
    if ! git rev-parse --abbrev-ref --symbolic-full-name merged-main-dev-$FUTURE_RELEASE@{u} &>/dev/null; then
      print_color "$COLOR_GREEN" "Setting tracking for 'merged-main-dev-$FUTURE_RELEASE' to follow 'upstream/main'."
      execute "git branch --set-upstream-to=upstream/main merged-main-dev-$FUTURE_RELEASE"
    fi
    print_color "$COLOR_GREEN" "Pulling updates with fast-forward only to bring 'merged-main-dev-$FUTURE_RELEASE' up-to-date."
    execute "git pull --ff-only"
  else
    print_color "$COLOR_GREEN" "Creating 'merged-main-dev-$FUTURE_RELEASE' based on 'upstream/main' and setting tracking."
    execute "git switch -c merged-main-dev-$FUTURE_RELEASE upstream/main"
    print_color "$COLOR_GREEN" "Setting upstream tracking to 'upstream/main' for 'merged-main-dev-$FUTURE_RELEASE'."
    execute "git branch --set-upstream-to=upstream/main merged-main-dev-$FUTURE_RELEASE"
  fi
}

push_branch() {
  print_heading $COLOR_PURPLE "Pushing 'merged-main-dev-$FUTURE_RELEASE' to your GitHub fork, preparing for pull request:"
  execute "git push origin merged-main-dev-$FUTURE_RELEASE"
  print_color "$COLOR_GREEN" "Successfully pushed 'merged-main-dev-$FUTURE_RELEASE' to your GitHub fork!"
  print_color "$COLOR_YELLOW" "To create a PR, visit: https://github.com/kubernetes/website/compare/dev-${FUTURE_RELEASE}...${YOUR_USER}:${REPO_NAME}:merged-main-dev-${FUTURE_RELEASE}"
  print_color "$COLOR_YELLOW" "For the PR use the Title: Merge main into dev-${FUTURE_RELEASE}"
  print_color "$COLOR_YELLOW" "See: https://github.com/kubernetes/$REPO_NAME/pull/16225 as an example."
}

# Execution Flow
initialize_local_fork
configure_upstream_remote
update_local_branches_from_upstream
prepare_release_branch
sync_release_branch_with_main
manage_merged_release_branch

# Push Confirmation or Auto Push
if [ "$AUTO_PUSH" = true ]; then
  push_branch
else
  if prompt_confirmation "Do you want to push the changes to origin?"; then
    push_branch
  else
    print_color "$COLOR_YELLOW" "Changes were not pushed to origin."
    print_color "$COLOR_GREEN" "You can manually push using the following command:"
    print_color "$COLOR_GREEN" "git push origin merged-main-dev-$FUTURE_RELEASE"
  fi
fi
