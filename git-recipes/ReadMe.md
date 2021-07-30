### Real World GitHub Recipes

* Git [How to](https://github.com/git-guides/install-git) and [Git Handbook](https://guides.github.com/introduction/git-handbook/)
* GitHub command line tool: https://cli.github.com/manual/

#### Start a new local repo (assumes there is not currently an active remote GitHub repo)

| Command | Description |
| --- | --- |
| `mkdir /home/user/Desktop/name_of_repo` | Make a project folder |
| `cd /home/user/Desktop/name_of_repo` | Change directory path to the `name_of_repo` folder |
| `git init name_of_repo` | Transform the current directory into a Git repository. Creates a hidden directory called `.git` storing all the objects and refs that Git uses to version control |
| `touch README.md` | Create the first file in the project |
| `open -t README.md` | Add text to the first file |
| `git add README.md` | Git isn't aware of the file so stage |


#### Add, update, and delete files and folders to a commit staging area (before pushing to remote repo) 
| Command | Description |
| --- | --- |
| `cd /home/user/Desktop/name_of_repo` | Change directory path to the `name_of_repo` folder |
| `git add filename.txt` | Add a file to staging |
| `rm filename.txt` <br />`git add` | Stage deleted files |
| `git add -A` | Stage everything (all new, modified, and deleted files, including files in the current directory and in higher directories) |
| `git add .` | Stage the entire current directory recursively without higher directories |
| `git add -u` | Stages new and modified files only, NOT deleted files |
| `git add /home/user/Desktop/name_of_repo/repo-subfolder/` | Stage all changes to all files within a repo subfolder |
| `git commit -m "add README to initial commit"` | Create a commit which takes a snapshot of the staging area of will be pushed to GitHub |

#### Editing and undoing commits 
| Command | Description |
| --- | --- |
| `cd /home/user/Desktop/name_of_repo` | Change directory path to the `name_of_repo` folder |
| `git commit --amend -m "descriptive commit message"` | Replaces the most recent commit with a new commit, this is useful when commit contains changes you want to adjust |
| `git revert` | Safest way to undo commit (looks at the changes introduced by a commit, then applies the inverse of those changes in a new commit) |
| `git checkout -- filename.txt` | Restore a file to the way it was on the previous commit. Git will assume you want to checkout HEAD so use `git diff` to confirm |
| `git checkout <hash> -- filename.txt` | Restore a specific commit and file. Find the commit `<hash>` like this: `https://github.com/<account>/<repo>/commit/<hash>` |
| `git reset --soft HEAD` | Undo last commit (doesn't undo add so changes are left staged) |
| `git reset --mixed HEAD` | Undo last commit, undo add / unstage changes (changes are left in working tree) |
| `git reset --hard HEAD` | Undo last commit, undo add / unstage changes, delete any changes you made on the codes (this is the same as `git checkout HEAD`) |
| `git reset --hard <hash>` | If you don't want to use HEAD use the `<hash>` from last good commit. The commit `<hash>` found here `https://github.com/<account>/<repo>/commit/<hash>` |

#### Recovering lost changes
| Command | Description |
| --- | --- |
| `cd /home/user/Desktop/name_of_repo` | Change directory path to the `name_of_repo` folder |
| `git reflog` | Produce log of every commit that HEAD has pointed to if you unintentionally lose commits, you can find and access (use `git checkout` to bring back lost files) |
| `git log` | Browse and inspect the evolution of project files |
| `git checkout path/to/file-I-want-to-bring-back.txt` | Recover SINGLE file if you accidently did a `git reset --hard HEAD` or `git checkout HEAD` |
| `git ls-files -z -d | xargs -0 git checkout --` | Recover all UNSTAGED deletions without specifying each single path (WARNING be sure this is what you want) |
| `git status | grep 'deleted:' | awk '{print $2}' | xargs git checkout --` | Recover all STAGED deletions without specifying each single path (WARNING be sure this is what you want) |

#### Pushing commits in local repo to remote GitHub repo
| Command | Description |
| `git remote -v` | List the current remotes associated with the local repository |
| `git remote add origin https://github.com/<useraccount>/<name_of_repo>.git` | Add a remote repo to GitHub for a newly initialized repository (`origin` is the default name for the URL that the remote repository) |
| `git push -u origin master` | When pushing a branch for the first time, push will configure the relationship between the remote and your local repository so that you can use git pull and git push with no additional options in the future. In this case `origin` refers to the repo URL and `master` is the checked out branch |
| `git push --set-upstream origin master` | Uploads all local branch commits to the remote (`upstream` refers to the remote repository, `origin` refers to repo URL, and `master` refers to the checked out branch) |

#### Contribute to an existing remote repo that you don't have cloned locally
| Command | Description |
| `cd /home/user/Desktop` | Set current directory folder to clone repo |
| `git clone git@github.com:github_account/name_of_repo.git` | Download a repository from GitHub.com to machine (clones repo, master and all of the remote tracking branches) |
| `cd /home/user/Desktop/name_of_repo` | Change into the `name_of_repo` directory |
| `git branch --all` | Review all local working branches |
| `git status` | Show what branch you're on, what files are in the working or staging directory |
| `git branch new-branch` | Create a new branch to store any new changes |
| `git checkout new-branch` | Switch to that branch |
| `open -t file1.md` <br /> `open -t file2.py` | Code and make changes to files in text editor (i.e., file1.md file2.py) |
| `git status -v` | Review on all text changes made to any uncommitted files (using verbose option) |
| `git add file1.md file2.py` | Stage the changed files |
| `git commit -m "descriptive message"` | Commit changed files (acts as a snapshot of the staging area recorded permanently) |
| `git push --set-upstream origin new-branch` | Push committed changes to github so that all local branch commits are uploaded to the remote | 
| `git push -u origin new-branch` | Push the changes to the remote branch |

#### Contribute to an existing remote branch on GitHub from a repo that is already local (assumes `name_of_repo` already exists on the machine and a new branch has been pushed to GitHub from someone else since the last time changes were made locally)
| Command | Description |
| `cd /home/user/Desktop/name_of_repo` | Change into the `name_of_repo` directory |
| `git status` | Check if local branch is ahead or behind on commits or if there are merge conflicts |
| `git status -v`  | Add verbose option |
| `git fetch` | Updates the remote tracking branches (useful when `git status` shows that there is a "merge conflict" i.e., when two different branches change the same file) |
| `git diff branch-1 branch-2` | Examine differences between branches that have a merge conflict |
| `git merge` | Update your current branch with any new commits on the remote tracking branch (do this after running git fetch and fixing the "merge conflict" between the two branches) |
| `git pull` | Update your local working checked out branch with commits from the remote, and update all remote tracking branches (combination of git fetch and git merge). Again make sure there are no merge conflicts first using `git status` |
| `git checkout other-branch` | Change into the existing branch called `other-branch` |
| `open -t filename.txt` | Make changes, for example, edit `filename.txt` using the text editor |
| `git add filename.txt` | Stage the changed file |
| `git commit -m "edit file1"` | Take a snapshot of the staging area |
| `git push` | Push local changes to github remote |

#### Special cases for git pull
| Command | Description |
| `git pull --rebase` | Update your local working branch with commits from the remote. Will rewrite history so any local commits occur after all new commits coming from the remote, avoiding a merge commit |
| `git pull --force` | To force Git to overwrite your current branch to match the remote tracking branch |
| `git pull --all` | Fetch all remotes - this is handy if you are working on a fork or in another use case with multiple remotes |

#### Rebasing and merging
| Command | Description |
| `git merge` | Combine changes made on two distinct branches. For example, a developer would merge when they want to combine changes from a feature branch into the main branch for deployment |
| `git checkout local-branch` <br /> `git merge master` | Merge remote changes to master to local branch - this is a safe non-destructive operation that will not change existing branches in any way but can lead to a more complicated project history |
| `git checkout feature` <br /> `git rebase master` | Incorporate all of the new commits in remote master to to local branch. This re-writes project history so its perfectly linear, but you can’t see when upstream changes were incorporated into the feature |
| `git push --force` | If the rebased branch conflicts with the remote master branch and you want to override when you push |

#### Using .gitignore to protect secret access tokens that you don't want to push to GitHub

| `cd /home/user/Desktop/name_of_repo` | Change into the `name_of_repo` directory |
| `touch .env` | Create an environment file |
| `open -t .env` | Open the environment file and add secret tokens |
| `touch .gitignore` | Create a .gitignore |
| `echo '.env' >> .gitignore` <br /> `echo '.vscode' >> .gitignore`  <br /> `echo '!.gitignore' >> .gitignore` | Add .env to the .gitignore (so secrets stay off GitHub) |
| `git rm --cached .env` <br /> `git rm --cached .env.*` | Remove .env from Git environment |
