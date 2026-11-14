# GitHub workflow

Repository: [pierre-teodoresco/taskomatic-ios](https://github.com/pierre-teodoresco/taskomatic-ios). SSH remote: `git@github.com:pierre-teodoresco/taskomatic-ios.git`.

## Branch policy

`main` is the only long-lived branch and the default branch. Pierre develops directly on it: commit, then push to `main`. Agents follow the same flow when Pierre asks them to push; no `dev` branch or promotion PR exists any more.

```sh
git switch main
git pull --ff-only
# work, commit
git push
```

A short-lived branch and a PR to `main` remain available when Pierre wants a review step for a given change. Contributors without write access use a fork and open their PR against `main`. Permission to contribute through a PR does not grant direct writes to `main`.

## Reviews and the maintainer bypass

[CODEOWNERS](../.github/CODEOWNERS) assigns every path to `@pierre-teodoresco`. For pull requests, the branch rules require one approval, code-owner approval and resolution of review threads; new reviewable commits invalidate stale approvals.

Pierre is the only bypass actor and may push directly to `main` as well as merge his own PRs. This permission also technically lets him bypass a missing review on someone else's PR; the intended workflow is to submit an approval before merging another person's contribution. The update restriction reserves direct writes and merges to him.

A separate ruleset blocks deletion and force pushes on `main`, without bypass actors, including Pierre. The repository owner can still edit the repository's rules; branch protections cannot remove that administrative power.

No CI status is required yet because the repository has no Actions workflow. Run the local checks documented in the README before pushing. Code-owner rules identify the authenticated GitHub account, not the display name or email in a Git commit. Tools authenticated as Pierre have Pierre's permissions: agents push to `main` only when Pierre asks in the session.

## Versioned configuration

The two definitions in [.github/rulesets](../.github/rulesets) describe the intended GitHub branch rules:

- `history.json`: no deletion or force push on `main`; no bypass.
- `main.json`: updates restricted to the maintainer, PR and review requirements for others; the maintainer may push directly.

The maintainer is identified by GitHub user ID `72601501` (`pierre-teodoresco`). If this repository is forked or transferred, review those IDs, CODEOWNERS and repository access before applying the definitions. Committing a JSON file does not change GitHub settings automatically.

Inspect the live configuration with an authenticated account that has repository administration access:

```sh
gh api repos/pierre-teodoresco/taskomatic-ios/rulesets \
  --jq '.[] | {id, name, enforcement}'
gh ruleset check main --repo pierre-teodoresco/taskomatic-ios
```

A ruleset whose JSON file was removed (such as the former `Dev` ruleset) must also be deleted on GitHub with `gh api --method DELETE repos/pierre-teodoresco/taskomatic-ios/rulesets/$RULESET_ID`.

To update an existing ruleset after reviewing its change, retrieve its ID from the listing, then apply the corresponding file. Keep the existing ID rather than creating a duplicate ruleset.

```sh
RULESET_ID='REPLACE_WITH_EXISTING_RULESET_ID'
gh api --method PUT \
  -H 'X-GitHub-Api-Version: 2026-03-10' \
  "repos/pierre-teodoresco/taskomatic-ios/rulesets/$RULESET_ID" \
  --input .github/rulesets/main.json
```

Read back the ruleset and check the effective rules for `main` after every update. Maintain the independent-review loop described in AGENTS.md for changes to CODEOWNERS or these definitions.

## GitHub Desktop

Use **File → Add Local Repository** to open this checkout; it already has the `origin` remote. Work on `main` and push from there. GitHub enforces the same rules for Desktop, command-line Git, the website and API clients. Desktop login does not replace SSH authentication for command-line Git; the SSH connection is verified separately during initial setup.

## GitHub references

- [Available branch rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets).
- [Bypass through pull requests only](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/creating-rulesets-for-a-repository#granting-bypass-permissions-for-your-branch-or-tag-ruleset).
- [Code owners](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners).
- [Approving a pull request](https://docs.github.com/en/pull-requests/how-tos/review-pull-requests/approving-a-pull-request-with-required-reviews).
