# Check if GIT_REPOS is set
if [ -z "$GIT_REPOS" ]; then
    exit 0
fi

# Split the space-separated list into an array
read -ra repos <<< "$GIT_REPOS"

repos_length=${#repos[@]}
if [ "$repos_length" -eq 1 ]; then
    echo "one size"
    # If there's only one repository, clone into the current directory
    git clone "${repos[0]}" .
else
# Loop through the array and clone repositories
for repo in "${repos[@]}"; do
    repo_name=$(basename "$repo" .git)  # Extract the repository name from the URL
    if [ ! -d "$repo_name" ]; then
        git clone "$repo"
    fi
done
fi
