
## Real World GitHub Recipes

* Git [How to](https://github.com/git-guides/install-git) and [Git Handbook](https://guides.github.com/introduction/git-handbook/)
* GitHub command line tool: https://cli.github.com/manual/

#### Start a new local repo (assumes there is not currently an active remote GitHub repo)
* Make a project folder <br />
`mkdir /home/user/Desktop/name_of_repo`  
* Change directory path to the `name_of_repo` folder <br />
`cd /home/user/Desktop/name_of_repo`  
* Transform the current directory into a Git repository. Creates a hidden directory called `.git` storing all the objects and refs that Git uses to version control <br />
`git init name_of_repo`  
* Create the first file in the project <br />
`touch README.md`  
* Add text to the first file <br />
`open -t README.md`  
* Git isn't aware of the file so stage <br />
`git add README.md`  

#### Add, update, and delete files and folders to a commit staging area (before pushing to remote repo) 
* Change directory path to the `name_of_repo` folder <br />
`cd /home/user/Desktop/name_of_repo`              
* Add a file to staging <br />
`git add filename.txt`
* Stage deleted files <br />
`rm filename.txt` <br />`git add`
* Stage everything (all new, modified, and deleted files, including files in the current directory and in higher directories)<br />
`git add -A` 
* Stage the entire current directory recursively without higher directories <br />
`git add .`  
* Stages new and modified files only, NOT deleted files <br />
`git add -u` 
* Stage all changes to all files within a repo subfolder <br />
`git add /home/user/Desktop/name_of_repo/repo-subfolder/` 
* Create a commit which takes a snapshot of the staging area of will be pushed to GitHub <br />
`git commit -m "add commit"`            

#### Editing and undoing commits 
* Change directory path to the `name_of_repo` folder  <br />
`cd /home/user/Desktop/name_of_repo` 
* Replaces the most recent commit with a new commit, this is useful when commit contains changes you want to adjust  <br />
`git commit --amend -m "descriptive commit message"` 
* Safest way to undo commit (looks at the changes introduced by a commit, then applies the inverse of those changes in a new commit)  <br />
`git revert` 
* Restore a file to the way it was on the previous commit. Git will assume you want to checkout HEAD so use `git diff` to confirm  <br />
`git checkout -- filename.txt` 
* Restore a specific commit and file. Find the commit `<hash>` like this: `https://github.com/<account>/<repo>/commit/<hash>`  <br />
`git checkout <hash> -- filename.txt` 
* Undo last commit (doesn't undo add so changes are left staged)  <br />
`git reset --soft HEAD` 
* Undo last commit, undo add / unstage changes (changes are left in working tree)  <br />
`git reset --mixed HEAD`
* Undo last commit, undo add / unstage changes, delete any changes you made on the codes (this is the same as `git checkout HEAD`)   <br />
`git reset --hard HEAD` 
* If you don't want to use HEAD use the `<hash>` from last good commit. The commit `<hash>` found here `https://github.com/<account>/<repo>/commit/<hash>`  <br />
`git reset --hard <hash>` 

#### Recovering lost changes
* Change directory path to the `name_of_repo` folder  <br />
`cd /home/user/Desktop/name_of_repo` 
* Produce log of every commit that HEAD has pointed to if you unintentionally lose commits, you can find and access (use `git checkout` to bring back lost files)  <br />
`git reflog`  
* Browse and inspect the evolution of project files  <br />
`git log` 
* Recover SINGLE file if you accidently did a `git reset --hard HEAD` or `git checkout HEAD`  <br />
`git checkout path/to/file-to-bring-back.txt` 

#### Pushing commits in local repo to remote GitHub repo
* List the current remotes associated with the local repository <br />
`git remote -v` 
* Add a remote repo to GitHub for a newly initialized repository (`origin` is the default name for the URL that the remote repository) <br />
`git remote add origin https://github.com/<useraccount>/<name_of_repo>.git` 
* When pushing a branch for the first time, push will configure the relationship between the remote and your local repository so that you can use git pull and git push with no additional options in the future. In this case `origin` refers to the repo URL and `master` is the checked out branch <br />
`git push -u origin master` 
* Uploads all local branch commits to the remote (`upstream` refers to the remote repository, `origin` refers to repo URL, and `master` refers to the checked out branch) <br />
`git push --set-upstream origin master` 

#### Contribute to an existing remote repo that you don't have cloned locally
* Set current directory folder to clone repo <br />
`cd /home/user/Desktop` 
* Download a repository from GitHub.com to machine (clones repo, master and all of the remote tracking branches) <br />
`git clone git@github.com:github_account/name_of_repo.git` 
* Change into the `name_of_repo` directory <br />
`cd /home/user/Desktop/name_of_repo` 
* Review all local working branches <br />
`git branch --all` 
* Show what branch you're on, what files are in the working or staging directory <br />
`git status` 
* Create a new branch to store any new changes <br />
`git branch new-branch` 
* Switch to that branch <br />
`git checkout new-branch`  
* Code and make changes to files in text editor (i.e., file1.md file2.py) <br />
`open -t file1.md` <br /> `open -t file2.py` 
* Review on all text changes made to any uncommitted files (using verbose option) <br />
`git status -v` 
* Stage the changed files <br />
`git add file1.md file2.py` 
* Commit changed files (acts as a snapshot of the staging area recorded permanently) <br />
`git commit -m "descriptive message"` 
* Push committed changes to github so that all local branch commits are uploaded to the remote <br />
`git push --set-upstream origin new-branch` 
* Push the changes to the remote branch <br />
`git push -u origin new-branch` 

#### Contribute to an existing remote branch on GitHub from a repo that is already local (assumes `name_of_repo` already exists on the machine and a new branch has been pushed to GitHub from someone else since the last time changes were made locally)
* Change into the `name_of_repo` directory <br />
`cd /home/user/Desktop/name_of_repo` 
* Check if local branch is ahead or behind on commits or if there are merge conflicts <br />
`git status` 
* Add verbose option <br />
`git status -v`  
* Updates the remote tracking branches (useful when `git status` shows that there is a "merge conflict" i.e., when two different branches change the same file) <br />
`git fetch` 
* Examine differences between branches that have a merge conflict<br /> 
`git diff branch-1 branch-2` 
* Update your current branch with any new commits on the remote tracking branch (do this after running git fetch and fixing the "merge conflict" between the two branches) <br />
`git merge`
* Update your local working checked out branch with commits from the remote, and update all remote tracking branches (combination of git fetch and git merge). Again make sure there are no merge conflicts first using `git status`) <br />
`git pull` 
* Change into the existing branch called `other-branch` <br />
`git checkout other-branch` 
* Make changes, for example, edit `filename.txt` using the text editor <br />
`open -t filename.txt`
* Stage the changed file  <br />
`git add filename.txt`
* Take a snapshot of the staging area <br />
`git commit -m "edit file1"` 
* Push local changes to github remote <br />
`git push` 

#### Special cases for git pull
* Update your local working branch with commits from the remote. Will rewrite history so any local commits occur after all new commits coming from the remote, avoiding a merge commit <br />
`git pull --rebase` 
* To force Git to overwrite your current branch to match the remote tracking branch  <br />
`git pull --force` 
* Fetch all remotes - this is handy if you are working on a fork or in another use case with multiple remotes <br />
`git pull --all` 

#### Rebasing and merging
* Combine changes made on two distinct branches. For example, a developer would merge when they want to combine changes from a feature branch into the main branch for deployment <br />
`git merge` 
* Merge remote changes to master to local branch - this is a safe non-destructive operation that will not change existing branches in any way but can lead to a more complicated project history <br />
`git checkout local-branch` <br /> `git merge master` 
* Incorporate all of the new commits in remote master to to local branch. This re-writes project history so its perfectly linear, but you can’t see when upstream changes were incorporated into the feature <br />
`git checkout feature` <br /> `git rebase master` 
* If the rebased branch conflicts with the remote master branch and you want to override when you push <br />
`git push --force` 

#### Using .gitignore to protect secret access tokens that you don't want to push to GitHub
* Change into the `name_of_repo` directory <br />
`cd /home/user/Desktop/name_of_repo` 
* Create an environment file <br />
`touch .env`
* Open the environment file and add secret tokens <br />
`open -t .env` 
* Create a .gitignore <br />
`touch .gitignore`  
* Add .env to the .gitignore (so secrets stay off GitHub) <br />
`echo '.env' >> .gitignore` <br /> `echo '.vscode' >> .gitignore`  <br /> `echo '!.gitignore' >> .gitignore` 
* Remove .env from Git environment <br />
`git rm --cached .env` <br /> `git rm --cached .env.*` 

#### Other Tips

#### Special clone operations
* Clone only a single branch <br />
`git clone git@github.com:github_account/name_of_repo.git --branch name_of_branch --single-branch`
* Populate the working directory with all of the files present in the root directory <br />
`git clone git@github.com:github_account/name_of_repo.git --branch name_of_branch --sparse`

#### Setting up Git for the first time on Midway HPC
* SSH into Midway `ssh <cnetid>@midway2.rcc.uchicago.edu`
* Set current directory to home with `cd` 
* Run `ssh-keygen` and hit 'enter' at every prompt i.e., leave the following blank `Enter file in which to save the key (/home/user/.ssh/id_rsa):`, `Enter passphrase (empty for no passphrase):`, `Enter same passphrase again:`
* Set `cd ~/.ssh` and copy SSH key (view SSH key with `less id_rsa.pub` and hit `q` to exit)
* Go to github.com, click 'Settings' > 'SSH and GPG keys' > 'New SSH key' and paste in contents of `~/.ssh/id_rsa.pub` and save.
* Clone private repo to Midway: `git clone git@github.com:github_account/name_of_repo.git`

#### Hard recovery 
* Recover all UNSTAGED deletions without specifying each single path (WARNING be sure this is what you want)  
`git ls-files -z -d | xargs -0 git checkout --` | 
* Recover all STAGED deletions without specifying each single path (WARNING be sure this is what you want) 
`git status | grep 'deleted:' | awk '{print $2}' | xargs git checkout --` 
