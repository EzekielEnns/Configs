[setup ssh](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)
[setup ssh with git](https://superuser.com/questions/232373/how-to-tell-git-which-private-key-to-use)
`git pull reset --soft` then pull the changes and continue


for when your committing to places that require reporting:
    `git commit -am "$(git rev-parse --abbrev-ref HEAD) what i did`

if you have a file that you need to change i.e. a vite config or something and 
    its only for your machine use `git update-index --assume-unchanged path/to/your/file`
    these are git flags that change how git treats a file read more [here](https://git-scm.com/docs/git-update-index)

