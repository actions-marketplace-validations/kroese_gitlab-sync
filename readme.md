<h1 align="center">GitLab Sync<br />
<div align="center">
  
  [![Build](https://github.com/action-pack/gitlab-sync/workflows/Build/badge.svg)](https://github.com/action-pack/gitlab-sync/)
  [![Version](https://img.shields.io/github/v/tag/action-pack/gitlab-sync?label=version&sort=semver&color=066da5)](https://github.com/marketplace/actions/gitlab-sync)
  [![Size](https://img.shields.io/github/languages/code-size/action-pack/gitlab-sync?label=size&color=066da5)](https://github.com/action-pack/gitlab-sync/)
  
</div></h1>

GitHub Action to mirror a repository to GitLab.

## Usage 🚀

```yaml
name: GitLab Sync
on: [push, create, delete, workflow_dispatch]

jobs:
  sync:
    name: GitLab Sync
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4
        with:
          # Required to mirror all branches and tags.
          fetch-depth: 0

      - uses: action-pack/gitlab-sync@v3
        with:
          username: your-gitlab-username
          url: https://gitlab.com/your-gitlab-namespace/your-repo.git
          # Personal access token with write access to the target GitLab repository.
          token: ${{ secrets.GITLAB_TOKEN }}
```

## Notes

On GitLab.com, create a personal access token with the `write_repository` scope and save it as a GitHub secret, for example `GITLAB_TOKEN`. The target repository must already exist.

## Stars 🌟
[![Stargazers](https://raw.githubusercontent.com/star-stats/stars/refs/heads/data/charts/action-pack-gitlab-sync.svg)](https://github.com/action-pack/gitlab-sync/stargazers)
