# GitHub workflow

Repository: [pierre-teodoresco/taskomatic-ios](https://github.com/pierre-teodoresco/taskomatic-ios). SSH remote: `git@github.com:pierre-teodoresco/taskomatic-ios.git`.

## Branch policy

| Branch | Purpose | Direct writes | Pull requests |
| --- | --- | --- | --- |
| `dev` | Integration and everyday development | Pierre only; prefer a feature branch and a PR | Pierre reviews and merges contributions |
| `main` | Stable version; default branch | Changes must go through a PR, including Pierre's | Pierre reviews contributions and controls merging |

Start feature and fix branches from `dev`, open their PRs against `dev`, then promote the validated version with a PR from `dev` to `main`. Use a merge commit for `dev` → `main` to keep the ancestry of these long-lived branches aligned. Automatic deletion of merged branches stays disabled so promotion does not remove `dev`.

```sh
git switch dev
git pull --ff-only
git switch -c feature/short-description
```

Contributors without write access use a fork and target this repository's `dev` branch. Permission to contribute through a PR does not grant direct writes to `dev` or `main`.

## Reviews and the solo-maintainer exception

[CODEOWNERS](../.github/CODEOWNERS) assigns every path to `@pierre-teodoresco`. The branch review rules require one approval, code-owner approval and resolution of review threads. New reviewable commits invalidate stale approvals.

GitHub does not let a PR author approve their own PR. Pierre therefore has an explicit, auditable bypass of the review rules: through a PR only on `main`, and also for direct writes on `dev`. He can merge his own PR after inspecting it. This permission also technically lets him bypass a missing review on someone else's PR; the intended workflow is to submit an approval before merging another person's contribution. No other account receives this exception.

The update restriction also reserves PR merges to Pierre. A separate ruleset blocks deletion and force pushes on both branches, without bypass actors, including Pierre. The repository owner can still edit the repository's rules; branch protections cannot remove that administrative power.

No CI status is required yet because the repository has no Actions workflow. Run the local checks documented in the README before merging. Code-owner rules identify the authenticated GitHub account, not the display name or email in a Git commit. Tools authenticated as Pierre have Pierre's permissions; agents should follow the PR workflow and leave the human approval and merge decision to him unless he explicitly delegates it.

## Versioned configuration

The three definitions in [.github/rulesets](../.github/rulesets) describe the intended GitHub branch rules:

- `history.json`: no deletion or force push on `main` or `dev`; no bypass.
- `main.json`: updates restricted to the maintainer, PR and review requirements; maintainer bypass through PRs only.
- `dev.json`: updates restricted to the maintainer, PR and review requirements; maintainer may also push directly.

The maintainer is identified by GitHub user ID `72601501` (`pierre-teodoresco`). If this repository is forked or transferred, review those IDs, CODEOWNERS and repository access before applying the definitions. Committing a JSON file does not change GitHub settings automatically.

Inspect the live configuration with an authenticated account that has repository administration access:

```sh
gh api repos/pierre-teodoresco/taskomatic-ios/rulesets \
  --jq '.[] | {id, name, enforcement}'
gh ruleset check main --repo pierre-teodoresco/taskomatic-ios
gh ruleset check dev --repo pierre-teodoresco/taskomatic-ios
```

To update an existing ruleset after reviewing its change, retrieve its ID from the listing, then apply the corresponding file. Keep the existing ID rather than creating a duplicate ruleset.

```sh
RULESET_ID='REPLACE_WITH_EXISTING_RULESET_ID'
gh api --method PUT \
  -H 'X-GitHub-Api-Version: 2026-03-10' \
  "repos/pierre-teodoresco/taskomatic-ios/rulesets/$RULESET_ID" \
  --input .github/rulesets/main.json
```

Read back the ruleset and check the effective rules for both branches after every update. Maintain the independent-review loop described in AGENTS.md for changes to CODEOWNERS or these definitions.

## GitHub Desktop

Use **File → Add Local Repository** to open this checkout; it already has the `origin` remote. Switch to `dev` for ordinary work and create a feature branch for a PR. GitHub enforces the same rules for Desktop, command-line Git, the website and API clients. Desktop login does not replace SSH authentication for command-line Git; the SSH connection is verified separately during initial setup.

## GitHub references

- [Available branch rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets).
- [Bypass through pull requests only](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/creating-rulesets-for-a-repository#granting-bypass-permissions-for-your-branch-or-tag-ruleset).
- [Code owners](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners).
- [Approving a pull request](https://docs.github.com/en/pull-requests/how-tos/review-pull-requests/approving-a-pull-request-with-required-reviews).
