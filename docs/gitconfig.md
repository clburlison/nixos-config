# Private Git overrides

`dotfiles/gitconfig` includes an optional private file after the default `[user]` settings:

```gitconfig
[include]
	path = ~/.gitconfig.local
```

To override your email only beneath a work directory, create `~/.gitconfig.local` outside this repo:

```gitconfig
[includeIf "gitdir:~/dev/work/"]
	path = ~/.gitconfig.work
```

The trailing `/` matches repositories anywhere beneath that directory. Replace the example directory with your own.

Create `~/.gitconfig.work`, also outside this repo:

```gitconfig
[user]
	email = you@example.com
```

Git skips missing include files. The work email overrides earlier defaults only in matching repositories; other repositories retain the default email. Repo-local settings and author/committer environment variables can still override the email.

Run `task switch` to activate changes to the managed global config. Edits to either private file take effect immediately once the include is active.

Verify from a work repository, then repeat outside the work directory to confirm the default email:

```sh
git config --show-origin --get user.email
git var GIT_COMMITTER_IDENT
```
