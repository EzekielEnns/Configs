[setup ssh](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)
[setup ssh with git](https://superuser.com/questions/232373/how-to-tell-git-which-private-key-to-use)
`git pull reset --soft` then pull the changes and continue


for when your committing to places that require reporting:
    `git commit -am "$(git rev-parse --abbrev-ref HEAD) what i did`




https://www.baeldung.com/ops/git-assume-unchanged-skip-worktree
this is wrong VVVV use skip working tree instead
if you have a file that you need to change i.e. a vite config or something and 
    its only for your machine use `git update-index --assume-unchanged path/to/your/file`
    these are git flags that change how git treats a file read more [here](https://git-scm.com/docs/git-update-index)


for forks
https://stackoverflow.com/questions/7244321/how-do-i-update-or-sync-a-forked-repository-on-github

```
# Add the remote, call it "upstream":

git remote add upstream https://github.com/whoever/whatever.git

# Fetch all the branches of that remote into remote-tracking branches

git fetch upstream

# Make sure that you're on your main branch:

git checkout main

# Rewrite your main branch so that any commits of yours that
# aren't already in upstream/main are replayed on top of that
# other branch:

git rebase upstream/main
```
fork reference
https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/getting-started/best-practices-for-pull-requests
