#!/bin/bash

# Function to select folder (uses zenity if available, else falls back to read)
select_folder() {
    local prompt="$1"
    local folder=""
    if command -v zenity >/dev/null 2>&1; then
        folder=$(zenity --file-selection --directory --title="$prompt")
        if [ $? -ne 0 ]; then
            echo "Folder selection cancelled. Exiting."
            exit 1
        fi
    else
        read -rp "$prompt: " folder
    fi
    echo "$folder"
}

# 1. Ask for private repo folder
private_repo=$(select_folder "Select the PRIVATE repository folder")
if [ ! -d "$private_repo" ]; then
    echo "Error: Private repository folder does not exist."
    exit 1
fi

# 2. Ask for public repo folder
public_repo=$(select_folder "Select the PUBLIC repository folder")
if [ ! -d "$public_repo" ]; then
    echo "Error: Public repository folder does not exist."
    exit 1
fi

# 3. Check git status in private repo
cd "$private_repo" || { echo "Failed to enter private repo directory."; exit 1; }
echo "Checking git status in private repo..."

# Fetch latest changes from remote
git fetch

# Check for uncommitted changes
if [[ -n $(git status --porcelain) ]]; then
    echo "There are uncommitted changes in the private repository."
    echo "Please commit and push all changes in the private repo before moving files to the public repo."
    exit 1
fi

# Check if local branch is behind remote
local_branch=$(git rev-parse --abbrev-ref HEAD)
local_commit=$(git rev-parse "$local_branch")
remote_commit=$(git rev-parse "origin/$local_branch")

if [ "$local_commit" != "$remote_commit" ]; then
    echo "Your private repository is not up to date with the remote."
    echo "Please pull or push all changes in the private repo before moving files to the public repo."
    exit 1
fi

# 4. Delete all files in public repo except .git
cd "$public_repo" || { echo "Failed to enter public repo directory."; exit 1; }
echo "Deleting files in public repo (excluding .git)..."
shopt -s dotglob
for item in "$public_repo"/* "$public_repo"/.*; do
    base_item=$(basename "$item")
    if [[ "$base_item" != "." && "$base_item" != ".." && "$base_item" != ".git" ]]; then
        rm -rf "$item"
    fi
done
shopt -u dotglob
if [ $? -ne 0 ]; then
    echo "Error deleting files in public repo. Please check permissions."
    exit 1
fi

# 5. Copy all files except .git from private repo to public repo
echo "Copying files from private repo (excluding .git)..."
shopt -s dotglob
for item in "$private_repo"/* "$private_repo"/.*; do
    base_item=$(basename "$item")
    if [[ "$base_item" != "." && "$base_item" != ".." && "$base_item" != ".git" ]]; then
        cp -r "$item" "$public_repo"/ 2>/dev/null
    fi
done
shopt -u dotglob
if [ $? -ne 0 ]; then
    echo "Error copying files. Please check permissions and paths."
    exit 1
fi

# 6. Execute git status in public repo
cd "$public_repo" || { echo "Failed to enter public repo directory."; exit 1; }
echo "Running git status..."
git status
if [ $? -ne 0 ]; then
    echo "Git status failed. Ensure this is a valid git repository."
    exit 1
fi

# 7. Execute git add --all
echo "Adding all changes..."
git add --all
if [ $? -ne 0 ]; then
    echo "Git add failed. Please check for git issues."
    exit 1
fi

# 8. Execute git commit
echo "Committing changes..."
git commit -m "Moved files from private repo to public repo"
if [ $? -ne 0 ]; then
    echo "Git commit failed. There may be nothing to commit or another issue."
    echo "Try running 'git status' and 'git add' manually."
    exit 1
fi

# 9. Execute git push
echo "Pushing to remote..."
git push
if [ $? -ne 0 ]; then
    echo "Git push failed. Please check your remote repository, authentication, and network connection."
    echo "Try running 'git push' manually and resolve any errors."
    exit 1
fi

# 10. Success message
echo "Success! Files moved from private repo to public repo and changes pushed."

exit 0