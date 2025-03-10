# tue

Install tue and deps only

```sh
mkdir -p cue.mod/pkg/github.com/abcue/tue/
curl -sSL https://github.com/abcue/tue/raw/main/tue.cue -o cue.mod/pkg/github.com/abcue/tue/tue.cue

mkdir -p cue.mod/pkg/github.com/abcue/cup/
curl -sSL https://github.com/abcue/cup/raw/main/cup.cue -o cue.mod/pkg/github.com/abcue/cup/cup.cue
```

Install tue with providers

```sh
brew install git-subrepo
mkdir -p cue.mod/pkg/github.com/abcue
git subrepo clone https://github.com/abcue/tue.git devops/cue.mod/pkg/github.com/abcue/tue
git subrepo clone https://github.com/abcue/cup.git devops/cue.mod/pkg/github.com/abcue/cup
```

TODO: publish to https://registry.cue.works