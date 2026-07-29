# Publishing to GitHub

## Install the publishing prerequisites

```bash
./scripts/install-github-cli.sh
```

This installs Git and GitHub CLI from GitHub's official signed APT repository.

The repository includes `publish-to-github.sh`, which:

1. authenticates through GitHub CLI when necessary;
2. initializes the local Git repository;
3. configures a private GitHub noreply commit identity when no local identity exists;
4. creates the initial commit;
5. creates the remote repository;
6. pushes `main`;
7. adds project topics;
8. updates the README clone URL;
9. creates and pushes the `v1.1.0` tag.

## Public repository

```bash
./publish-to-github.sh public
```

## Private repository

```bash
./publish-to-github.sh private
```

## Custom name or organization

```bash
./publish-to-github.sh public ORGANIZATION/kali-awus1900-deploy
```

The command is interactive only when GitHub CLI authentication is required.
