# Project Title

Bash script to use to perform weekly branch syncs for kubernetes release team

# Description

Each week the release docs team needs to merge the `main` branch into `dev-[future release]` branch in order to avoid merge conflicts on release day. This script executes the following commands (from the [release docs handbook](https://github.com/kubernetes/sig-release/blob/b51237ddb556bb6d24e43d7424e55cb9e66694d5/release-team/role-handbooks/docs/Release-Timeline.md#maintain-the-current-and-upcoming-dev-branch)): 
```
git clone git@github.com:{YOUR_USER}/website.git
cd website

# Step 0 (if you don't already have a remote called "upstream")
git remote add upstream https://github.com/kubernetes/website.git && git remote set-url --push upstream no_push

# Check your origin and upstream
git remote -v
# expected output
# origin	git@github.com:{YOUR_USER}/website.git (fetch)
# origin	git@github.com:{YOUR_USER}/website.git (push)
# upstream	https://github.com/kubernetes/website.git (fetch)
# upstream	no_push (push)

# Step 1
git fetch upstream main

# Step 2
git fetch upstream dev-[future release]

# Step 3
git checkout --track upstream/dev-[future release]

# Step 4 Fetches fast-forwards only, fetches if there is no divergence
git pull --ff-only # make sure you're up to date

# Step 5 Merge main into the dev-[future release] branch
# You might see merge conflicts at this point.
git merge upstream/main
# If there is a merge conflict, resolve the conflict
  # More on resolving merge conflicts: https://help.github.com/articles/resolving-a-merge-conflict-using-the-command-line/
  # e.g. git add ... and git commit -m "Merge main into dev-[future release] to keep in sync"
# If the merge has no conflict, git will open your editor (e.g. vi) and have you edit the merge commit
  # Edit (in vi, enter <i> to enter insert mode) the commit message to "Merge main into dev-[future release] to keep in sync"
  # Save the message (in vi, <esc> :wq)

# Step 6 Create a new branch that has main merged into the dev-[future release] branch
git checkout -b merged-main-dev-[future release]

# Step 7 Push the new branch to your local fork
git push origin merged-main-dev-[future release]

# Step 8 Create the PR
Go to your fork in a browser: https://www.github.com/{YOUR_USER}/website
Submit a PR against upstream `dev-[future release]` from your fork's branch `merged-main-dev-[future release]` by changing the
`base` from `main` to `dev-[future-release]` when creating the PR.
e.g. [Merge main into future release](https://github.com/kubernetes/website/pull/16225).
```

## Getting Started

### Installing

Download the script or clone this repo and add executable permissions to the script to allow it to run
```
chmod +x branch-sync.sh
```

## Usage

Usage: ./branch-sync.sh FUTURE_RELEASE [-p | --push] [-u | --user]
Options:
  -p, --push    Push the branch sync automatically
  -u, --user    Manually set github user
  -h, --help    Display this help message

### Example Start of Script

```
➜ ./branch-sync.sh 1.31 -u youruser   
USER: youruser
FUTURE_RELEASE: 1.31
AUTO_PUSH: false
Do you want to proceed with these values? (y/n):
```
