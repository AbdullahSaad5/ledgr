# Issue tracker: GitHub

Issues and PRDs for this repo live as GitHub issues on `AbdullahSaad5/ledgr`. Use the `gh` CLI for all operations.

## ⚠️ Auth on this machine (required for every gh command)

The default `gh` login is the **work** account (`abdullahsaaddtc`), which cannot see this private personal repo. The personal account (`AbdullahSaad5`) is also logged into gh's keyring. **Do not `gh auth switch`** (it's global and would break concurrent work sessions). Instead, prefix every gh command in this repo with the personal token:

```bash
GH_TOKEN=$(gh auth token -u AbdullahSaad5) gh issue list -R AbdullahSaad5/ledgr --state open
```

For a longer run of commands, export once per shell: `export GH_TOKEN=$(gh auth token -u AbdullahSaad5)`.

Git pushes are unaffected — they go over SSH with the personal key (`git push origin main`), never via `gh`.

## Wayfinder map for the v1.0 effort

The map is issue **#1** ([Wayfinder map: Ledgr v1.0 — zero to Play-ready release](https://github.com/AbdullahSaad5/ledgr/issues/1)); tickets #2–#13 are its sub-issues with native dependency edges. Frontier = open, unblocked, unassigned sub-issues.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body "..."`. Use a heredoc for multi-line bodies.
- **Read an issue**: `gh issue view <number> --comments`, filtering comments by `jq` and also fetching labels.
- **List issues**: `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'` with appropriate `--label` and `--state` filters.
- **Comment on an issue**: `gh issue comment <number> --body "..."`
- **Apply / remove labels**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **Close**: `gh issue close <number> --comment "..."`

Infer the repo from `git remote -v` — `gh` does this automatically when run inside a clone.

## Pull requests as a triage surface

**PRs as a request surface: no.** Solo project; external PRs are not expected. Revisit if the repo goes public and attracts contributors.

## When a skill says "publish to the issue tracker"

Create a GitHub issue.

## When a skill says "fetch the relevant ticket"

Run `gh issue view <number> --comments`.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a single issue with **child** issues as tickets.

- **Map**: a single issue labelled `wayfinder:map`, holding the Notes / Decisions-so-far / Fog body. `gh issue create --label wayfinder:map`.
- **Child ticket**: an issue linked to the map as a GitHub sub-issue (`gh api` on the sub-issues endpoint). Where sub-issues aren't enabled, add the child to a task list in the map body and put `Part of #<map>` at the top of the child body. Labels: `wayfinder:<type>` (`research`/`prototype`/`grilling`/`task`). Once claimed, the ticket is assigned to the driving dev.
- **Blocking**: GitHub's **native issue dependencies**. Add an edge with `gh api --method POST repos/<owner>/<repo>/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>`, where `<blocker-db-id>` is the blocker's numeric **database id** (`gh api repos/<owner>/<repo>/issues/<n> --jq .id`, _not_ the `#number` or `node_id`). GitHub reports `issue_dependencies_summary.blocked_by` (open blockers only — the live gate). Where dependencies aren't available, fall back to a `Blocked by: #<n>, #<n>` line at the top of the child body. A ticket is unblocked when every blocker is closed.
- **Frontier query**: list the map's open children (`gh issue list --state open`, scoped to the map's sub-issues / task list), drop any with an open blocker (`issue_dependencies_summary.blocked_by > 0`, or an open issue in the `Blocked by` line) or an assignee; first in map order wins.
- **Claim**: `gh issue edit <n> --add-assignee @me` — the session's first write.
- **Resolve**: `gh issue comment <n> --body "<answer>"`, then `gh issue close <n>`, then append a context pointer (gist + link) to the map's Decisions-so-far.

