#### Real World GitHub Recipes

* Git [How to](https://github.com/git-guides/install-git) and [Git Handbook](https://guides.github.com/introduction/git-handbook/)
* GitHub command line tool: https://cli.github.com/manual/

### Start a new local repo (assumes there is not currently an active remote GitHub repo)
* Make a project folder: `mkdir /home/user/Desktop/name_of_repo`
* Change directory path to the `name_of_repo` folder: `cd /home/user/Desktop/name_of_repo`
* Transform the current directory into a Git repository. Creates a hidden directory called `.git` storing all the objects and refs that Git uses to version control: `git init name_of_repo`
* Create the first file in the project: `touch README.md`
* Add text to the first file: `open -t README.md`
* Git isn't aware of the file so stage it: `git add README.md`
