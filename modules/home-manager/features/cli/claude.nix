{ ... }:
{
  home.file.".claude/settings.json" = {
    force = true;
    text = builtins.toJSON {
    enabledMcpjsonServers = [
      "pipeline-rag"
      "storybook"
      "playwright"
      "vercel"
    ];
    permissions = {
      allow = [
        # ── Core tool primitives ──────────────────────────────────────────
        "Read"
        "Glob"
        "Grep"
        "BashOutput"
        "Edit"
        "Write"
        "NotebookEdit"
        "TodoWrite"
        "WebFetch"
        "WebSearch"
        "Skill(*)"

        # ── Generic shell ops (read-only inspection + safe write) ────────
        "Bash(ls)"
        "Bash(ls *)"
        # NOTE: to bypass the rtk `ls`→`rtk ls` rewrite for raw output, use
        # `rtk proxy ls …` (allow-listed via `Bash(rtk proxy *)`), NOT `/bin/ls`.
        "Bash(pwd)"
        "Bash(cd *)"
        "Bash(echo *)"
        "Bash(cat *)"
        "Bash(head *)"
        "Bash(tail *)"
        "Bash(find *)"
        "Bash(grep *)"
        "Bash(rg *)"
        "Bash(wc *)"
        "Bash(which *)"
        "Bash(file *)"
        "Bash(stat *)"
        "Bash(du *)"
        "Bash(df *)"
        "Bash(tree *)"
        "Bash(env)"
        "Bash(printenv *)"
        "Bash(jq)"
        "Bash(jq *)"
        "Bash(yq)"
        "Bash(yq *)"
        "Bash(awk *)"
        "Bash(sort *)"
        "Bash(uniq *)"
        "Bash(diff *)"
        "Bash(cmp *)"
        "Bash(ps *)"
        "Bash(pgrep *)" # read-only process lookup (sibling of the allowed ps)
        "Bash(lsof *)"
        "Bash(mkdir -p *)"
        "Bash(touch *)"
        "Bash(mktemp)"
        "Bash(mktemp *)"
        "Bash(mktemp -d)"
        "Bash(cp *)"
        "Bash(mv *)"
        "Bash(ln -s *)"
        "Bash(ln -sfn *)"
        "Bash(chmod *)" # mode bits / +x — 777 variants denied below
        "Bash(bash -n *)"
        "Bash(printf *)"
        "Bash(seq *)"
        "Bash(date)"
        "Bash(date *)"
        "Bash(basename *)"
        "Bash(dirname *)"
        "Bash(realpath *)"
        "Bash(readlink *)"
        "Bash(xargs *)"
        # `timeout <dur> <cmd>` — a command WRAPPER, so NOT blanket-allowed:
        # `Bash(timeout *)` would let `timeout 5 git push --force` / `timeout 5 rm
        # -rf …` slip past the prefix-match deny list. Treated like rtk — scoped to
        # safe inner commands only; any other timeout-wrapped command still prompts.
        # (Compound forms `timeout 5 X; <danger>` are split + checked per-segment.)
        "Bash(timeout * pnpm test*)"
        "Bash(timeout * pnpm build*)"
        "Bash(timeout * pnpm dev*)"
        "Bash(timeout * pnpm storybook*)"
        "Bash(timeout * pnpm docs:dev*)"
        "Bash(timeout * curl http://localhost:*)"
        "Bash(timeout * curl -s http://localhost:*)"
        "Bash(timeout * bash $HOME/.claude/pipeline/scripts/*)"
        "Bash(timeout * node scripts/*)"
        "Bash(timeout * python3 scripts/*)"
        "Bash(tar tzf *)"
        "Bash(tar tvf *)"
        "Bash(node --version)"
        "Bash(npm --version)"
        "Bash(pnpm --version)"
        "Bash(npx --version)"

        # ── Git read-only ────────────────────────────────────────────────
        "Bash(git status)"
        "Bash(git status *)"
        "Bash(git diff)"
        "Bash(git diff *)"
        "Bash(git diff --stat)"
        "Bash(git diff --stat *)"
        "Bash(git diff --no-color *)"
        "Bash(git log)"
        "Bash(git log *)"
        "Bash(git show *)"
        "Bash(git branch)"
        "Bash(git branch *)"
        "Bash(git remote)"
        "Bash(git remote *)"
        "Bash(git config --get *)"
        "Bash(git config --list)"
        "Bash(git rev-parse *)"
        "Bash(git rev-list *)"
        "Bash(git ls-files *)"
        "Bash(git ls-tree *)"
        "Bash(git ls-remote *)"
        "Bash(git blame *)"
        "Bash(git merge-base *)"
        "Bash(git symbolic-ref *)"
        "Bash(git for-each-ref *)"
        "Bash(git reflog)"
        "Bash(git reflog *)"
        "Bash(git stash list)"
        "Bash(git stash show *)"
        "Bash(git tag)"
        "Bash(git tag *)"
        "Bash(git fetch)"
        "Bash(git fetch *)"
        "Bash(git pull)"
        "Bash(git pull *)"
        "Bash(git check-ignore *)"
        "Bash(git worktree list)"
        "Bash(git worktree list *)"

        # ── Git `-C <path>` (run in another repo — broad allow paired
        # with destructive-form denies below) ────────────────────────────
        "Bash(git -C *)"

        # ── Git write (local — no destructive history rewrites; see deny)
        "Bash(git add *)"
        "Bash(git commit *)"
        "Bash(git checkout -b *)"
        "Bash(git switch -c *)"
        "Bash(git switch *)" # switch to an existing branch (file-safe; no --discard by default). NOT `git checkout <branch>` — that form also discards files.
        "Bash(git stash)"
        "Bash(git stash push *)"
        "Bash(git stash save *)"
        "Bash(git stash pop)"
        "Bash(git stash pop *)"
        "Bash(git stash apply *)"
        "Bash(git stash drop *)"
        "Bash(git merge --no-commit --no-ff *)"
        "Bash(git merge --abort)"
        "Bash(git merge --continue)"
        "Bash(git rebase --abort)"
        "Bash(git rebase --continue)"
        "Bash(git rebase --skip)"
        "Bash(git cherry-pick --abort)"
        "Bash(git cherry-pick --continue)"
        "Bash(git revert --abort)"
        "Bash(git revert --continue)"

        # ── Git push: NOT global. Lives in each project's settings.local.json so
        # push is a per-project opt-in (outward action). Force/delete remain denied
        # below (bare + rtk-wrapped forms).

        # ── gh CLI (read + safe writes) ──────────────────────────────────
        "Bash(gh auth status)"
        "Bash(gh pr view *)"
        "Bash(gh pr list)"
        "Bash(gh pr list *)"
        "Bash(gh pr checks *)"
        "Bash(gh pr diff *)"
        # gh pr create: per-project (project settings.local.json), like git push.
        "Bash(gh pr comment *)"
        "Bash(gh pr review *)"
        "Bash(gh issue view *)"
        "Bash(gh issue list)"
        "Bash(gh issue list *)"
        "Bash(gh issue create *)"
        "Bash(gh issue comment *)"
        "Bash(gh repo view)"
        "Bash(gh repo view *)"
        "Bash(gh run list)"
        "Bash(gh run list *)"
        "Bash(gh run view *)"
        "Bash(gh run watch *)"
        "Bash(gh run rerun *)"
        "Bash(gh api *)"
        "Bash(gh workflow list)"
        "Bash(gh workflow list *)"
        "Bash(gh workflow view *)"
        "Bash(gh release list)"
        "Bash(gh release list *)"
        "Bash(gh release view *)"
        "Bash(gh secret list)"
        "Bash(gh secret list *)"
        "Bash(gh variable list)"
        "Bash(gh variable list *)"
        "Bash(gh variable get *)"
        "Bash(gh variable set *)"
        # rtk proxy: wildcard allowed per user decision (consolidate rtk allows here).
        # ⚠ TRADEOFF: `rtk proxy <cmd>` bypasses the rtk output filter AND the deny
        # list (e.g. `rtk proxy git push --force` would NOT be blocked). The scoped
        # forms below are now redundant but kept for documentation.
        "Bash(rtk proxy *)"
        "Bash(rtk proxy gh run view *)"
        "Bash(rtk proxy gh run list *)"
        "Bash(rtk proxy gh api *)"
        "Bash(rtk proxy gh pr view *)"
        "Bash(rtk proxy gh pr checks *)"
        "Bash(rtk proxy pnpm lint)"
        "Bash(rtk proxy pnpm lint *)"
        # ── rtk auto-rewrite forms (read-only only) ──────────────────────
        # The rtk hook rewrites verbose dev commands to `rtk <cmd>` for token
        # savings (RTK.md: `git status` -> `rtk git status`), which moves them
        # out from under BOTH the allow-list and the deny-list — so the bare
        # `find */grep *` allows don't cover them and `find ... | grep ...`
        # prompts. Mirror only the read-only forms rtk wraps (command set per
        # https://github.com/rtk-ai/rtk).
        #
        # HARD RULES (deny-list safety):
        #   - For tools with destructive subcommands (git, gh, docker) scope to
        #     the safe subcommand. NEVER `rtk git *` / `rtk docker *` — that
        #     re-opens `rtk git push --force` etc. past the deny-list.
        #   - NEVER `rtk *`, and never the generic wrappers `rtk test|err|smart|
        #     proxy|summary|verify *` — they take an arbitrary command and would
        #     wrap anything (`rtk err rm -rf /`).
        #   - Tests/lint run via `pnpm test`/`pnpm lint` (already allowed), not
        #     bare `vitest`/`eslint`, so their rtk wrappers are intentionally omitted.

        # filesystem / search / inspect (pure read-only)
        "Bash(rtk ls)"
        "Bash(rtk ls *)"
        "Bash(rtk tree)"
        "Bash(rtk tree *)"
        "Bash(rtk cat *)"
        "Bash(rtk find *)"
        "Bash(rtk grep *)"
        "Bash(rtk rg *)"
        "Bash(rtk diff *)"
        "Bash(rtk env)"
        "Bash(rtk json *)"

        # git under rtk — read-only subcommands + add/commit (writes). push is NOT
        # here: it's per-project local, and force/delete are denied below (incl. rtk).
        "Bash(rtk git status)"
        "Bash(rtk git status *)"
        "Bash(rtk git log)"
        "Bash(rtk git log *)"
        "Bash(rtk git diff)"
        "Bash(rtk git diff *)"
        "Bash(rtk git show *)"
        "Bash(rtk git branch)"
        "Bash(rtk git branch *)"
        "Bash(rtk git add *)"
        "Bash(rtk git commit *)"

        # gh — read-only subcommands only
        "Bash(rtk gh pr list)"
        "Bash(rtk gh pr list *)"
        "Bash(rtk gh pr view *)"
        "Bash(rtk gh pr checks *)"
        "Bash(rtk gh issue list)"
        "Bash(rtk gh issue list *)"
        "Bash(rtk gh run list)"
        "Bash(rtk gh run list *)"
        "Bash(rtk gh run view *)"

        # docker — read-only subcommands only
        "Bash(rtk docker ps)"
        "Bash(rtk docker ps *)"
        "Bash(rtk docker images)"
        "Bash(rtk docker images *)"
        "Bash(rtk docker logs *)"
        "Bash(rtk docker compose ps *)"
        "Bash(rtk docker compose logs *)"
        "Bash(node --check *)"
        "Bash(shasum *)"
        # Makefile dev loop (non-destructive targets only). Deliberately NOT
        # `make dev-reset` (drops the DB volume) and NOT `make *` — destructive
        # targets must still prompt.
        "Bash(make)"
        "Bash(make help)"
        "Bash(make dev-up)"
        "Bash(make dev-down)"
        "Bash(make migrate)"
        "Bash(make seed)"
        "Bash(gh label list)"
        "Bash(gh label list *)"
        "Bash(gh search *)"

        # ── pnpm / npm ───────────────────────────────────────────────────
        "Bash(pnpm test)"
        "Bash(pnpm test *)"
        "Bash(pnpm test:*)"
        "Bash(pnpm lint)"
        "Bash(pnpm lint *)"
        "Bash(pnpm lint:*)"
        "Bash(pnpm typecheck)"
        "Bash(pnpm typecheck *)"
        "Bash(pnpm format)"
        "Bash(pnpm format *)"
        "Bash(pnpm build)"
        "Bash(pnpm build *)"
        "Bash(pnpm build:*)"
        "Bash(pnpm build-storybook)"
        "Bash(pnpm build-storybook *)"
        "Bash(pnpm verify)"
        "Bash(pnpm verify *)"
        "Bash(pnpm verify:*)"
        "Bash(pnpm quality)"
        "Bash(pnpm quality *)"
        "Bash(pnpm quality:*)"
        "Bash(pnpm doc-lint)"
        "Bash(pnpm doc-lint *)"
        "Bash(pnpm doc-lint:*)"
        "Bash(pnpm exec *)"
        "Bash(pnpm drizzle-kit *)"
        "Bash(pnpm db:*)"
        "Bash(bash scripts/*)"
        "Bash(bash scripts/*.sh)"
        "Bash(node scripts/*)"
        "Bash(python3 scripts/*)"
        "Bash(python scripts/*)"
        # node --test scoped to the pipeline's own kg/rag/graphify fixtures only (run from the pipeline repo root), not blanket
        "Bash(node --test kg/*)"
        "Bash(node --test rag/*)"
        "Bash(node --test graphify/*)"
        "Bash(pnpm dev)"
        "Bash(pnpm dev *)"
        "Bash(pnpm dev:*)"
        "Bash(pnpm start)"
        "Bash(pnpm start *)"
        "Bash(pnpm storybook)"
        "Bash(pnpm storybook *)"
        "Bash(pnpm test-storybook)"
        "Bash(pnpm test-storybook *)"
        "Bash(pnpm lighthouse)"
        "Bash(pnpm lighthouse *)"
        "Bash(pnpm docs:build)"
        "Bash(pnpm docs:dev)"
        "Bash(pnpm docs:dev *)"
        "Bash(pnpm prisma:generate)"
        "Bash(pnpm prisma:studio)"
        "Bash(pnpm prisma:migrate:dev)"
        "Bash(pnpm prisma:migrate:deploy)"
        "Bash(pnpm audit)"
        "Bash(pnpm audit *)"
        "Bash(pnpm list)"
        "Bash(pnpm list *)"
        "Bash(pnpm ls)"
        "Bash(pnpm ls *)"
        "Bash(pnpm view *)"
        "Bash(pnpm why *)"
        "Bash(pnpm outdated)"
        "Bash(pnpm outdated *)"
        "Bash(pnpm search *)"
        "Bash(npm view *)"
        "Bash(npm info *)"
        "Bash(npm search *)"

        # ── Formatter (direct prettier invocation) ───────────────────────
        # `pnpm format` / `pnpm exec *` are covered above. These cover direct
        # prettier runs — including the ./node_modules/.bin form used when the
        # rtk hook mangles bare `prettier` / `npx prettier` (returns no output).
        "Bash(prettier *)"
        "Bash(npx prettier *)"
        "Bash(./node_modules/.bin/prettier *)"

        # ── Pipeline scripts (global home-manager path) ──────────────────
        # The broad pattern covers any pipeline script invocation; specific
        # patterns kept for documentation of common entry points.
        "Bash(bash $HOME/.claude/pipeline/scripts/*)"
        "Bash($HOME/.claude/pipeline/scripts/*)"
        # Env-prefixed form: only scaffold-ticket/openapi/component.sh read
        # PIPELINE_HOME; an agent may prepend the correct value when the
        # inherited env var is stale. Safe — it only sets PIPELINE_HOME and then
        # runs an already-allow-listed pipeline script. (The leading assignment
        # otherwise breaks the prefix-match above and forces an approval prompt.)
        "Bash(PIPELINE_HOME=* bash $HOME/.claude/pipeline/scripts/*)"
        "Bash(PIPELINE_HOME=* $HOME/.claude/pipeline/scripts/*)"
        "Bash(bash $HOME/.claude/pipeline/scripts/validate-scripts.sh)"
        "Bash(bash $HOME/.claude/pipeline/scripts/check-env-compose-drift.sh)"
        "Bash(bash $HOME/.claude/pipeline/scripts/check-ports.sh)"
        "Bash(bash $HOME/.claude/pipeline/scripts/pipeline-status.sh)"
        "Bash(bash $HOME/.claude/pipeline/scripts/quality-gate.sh)"
        "Bash(bash $HOME/.claude/pipeline/scripts/dev-up.sh)"
        "Bash(bash $HOME/.claude/pipeline/scripts/dev-up.sh *)"
        "Bash(bash $HOME/.claude/pipeline/scripts/dev-db-setup.sh)"
        "Bash(bash $HOME/.claude/pipeline/scripts/pipeline-gc.sh)"
        "Bash(bash $HOME/.claude/pipeline/scripts/pipeline-gc.sh *)"
        "Bash(bash $HOME/.claude/pipeline/scripts/graphify-here.sh)"
        "Bash(bash $HOME/.claude/pipeline/scripts/graphify-here.sh *)"
        "Bash(bash $HOME/.claude/pipeline/scripts/update-skills.sh)"
        "Bash(bash $HOME/.claude/pipeline/scripts/update-skills.sh *)"

        # ── Pipeline KG / RAG / graphify direct node invocation ──────────
        # The kg/ingest.js + scripts/check-*.mjs are invoked directly with
        # `node` for CLI testing / debugging; the MCP server invokes them
        # internally and doesn't need an allow entry.
        "Bash(node $HOME/.claude/pipeline/kg/*)"
        "Bash(node $HOME/.claude/pipeline/kg/ingest.js *)"
        "Bash(node $HOME/.claude/pipeline/scripts/*)"
        "Bash(graphify *)"

        # ── External tools (assets, security, validation, local probes) ──
        "Bash(sqlite3 *)"
        "Bash(ffmpeg *)"
        "Bash(svgo *)"
        "Bash(oxipng *)"
        "Bash(sharp *)"
        "Bash(mozjpeg *)"
        "Bash(gitleaks *)"
        "Bash(spectral *)"
        "Bash(npx spectral *)"
        "Bash(curl http://localhost:*)"
        "Bash(curl -s http://localhost:*)"
        "Bash(curl -sS http://localhost:*)"
        "Bash(curl -sI http://localhost:*)"
        "Bash(curl -o /dev/null *)"

        # ── Performance audit tooling (Phase 10 — measurement + localhost load) ──
        # Scoped to the perf surfaces, NOT blanket `node *` / `npx *`. The perf
        # harnesses (autocannon, lighthouse Node API) live under tests/performance/;
        # bundle size is measured via `gzip -c … | wc -c` (both segments now allow-
        # listed, so the compound auto-approves); load tests hit localhost/127.0.0.1;
        # the dev server is started (`pnpm start`, allowed) and killed around the run.
        # (`pnpm exec lhci|autocannon|size-limit` is already covered by `pnpm exec *`.)
        "Bash(node tests/*)"
        "Bash(gzip *)" # reversible compression — gzip-size measurement, not destructive
        "Bash(gunzip *)"
        "Bash(zcat *)"
        "Bash(curl http://127.0.0.1:*)"
        "Bash(curl -s http://127.0.0.1:*)"
        "Bash(curl -sS http://127.0.0.1:*)"
        "Bash(curl -sI http://127.0.0.1:*)"
        "Bash(npx lhci *)"
        "Bash(npx autocannon *)"
        "Bash(npx size-limit *)"
        "Bash(npx lighthouse *)"
        "Bash(kill *)" # stop the backgrounded dev server after the load test
        "Bash(pkill *)"

        # ── Docker (read-only) ───────────────────────────────────────────
        "Bash(docker ps)"
        "Bash(docker ps *)"
        "Bash(docker logs *)"
        "Bash(docker compose ps)"
        "Bash(docker compose ps *)"
        "Bash(docker compose logs)"
        "Bash(docker compose logs *)"
        "Bash(docker compose config)"
        "Bash(docker compose config *)"
        # compose lifecycle (write). NOTE: `down -v` destroys volumes — accepted;
        # the dev loop normally goes through the allowed `make dev-up/dev-down`.
        "Bash(docker compose up)"
        "Bash(docker compose up *)"
        "Bash(docker compose down)"
        "Bash(docker compose down *)"
        "Bash(docker images)"
        "Bash(docker images *)"
        "Bash(docker version)"
        "Bash(docker info)"

        # ── Nix / system management ──────────────────────────────────────
        "Bash(darwin-rebuild switch *)"
        "Bash(sudo darwin-rebuild switch *)"
        "Bash(nix flake check *)"
        "Bash(nix flake show *)"
        "Bash(nix flake metadata *)"
        "Bash(nix-store --query *)"
        "Bash(nix-instantiate --parse *)" # syntax-check a .nix file (parse only — no eval/build)

        # ── macOS launchd (read-only introspection) ──────────────────────
        # getenv/list only. setenv/unsetenv/bootout/kickstart mutate → still prompt.
        "Bash(launchctl getenv *)"
        "Bash(launchctl list)"
        "Bash(launchctl list *)"

        # ── Claude Code self-introspection (read-only) ───────────────────
        # `claude mcp list/get` only. `claude mcp add/remove` mutate config → prompt.
        # NEVER `claude *` (could spawn nested sessions).
        "Bash(claude mcp list)"
        "Bash(claude mcp list *)"
        "Bash(claude mcp get *)"

        # ── MCP: Pencil ──────────────────────────────────────────────────
        "mcp__pencil__open_document"
        "mcp__pencil__get_editor_state"
        "mcp__pencil__get_screenshot"
        "mcp__pencil__get_variables"
        "mcp__pencil__batch_get"
        "mcp__pencil__snapshot_layout"
        "mcp__pencil__get_guidelines"
        "mcp__pencil__find_empty_space_on_canvas"
        "mcp__pencil__search_all_unique_properties"
        "mcp__pencil__export_nodes"
        "mcp__pencil__batch_design"
        "mcp__pencil__set_variables"
        "mcp__pencil__replace_all_matching_properties"

        # ── MCP: Pipeline RAG ────────────────────────────────────────────
        "mcp__pipeline-rag__query"
        "mcp__pipeline-rag__list_documents"
        "mcp__pipeline-rag__reindex"

        # ── MCP: Pipeline KG ─────────────────────────────────────────────
        "mcp__pipeline-kg__stats"
        "mcp__pipeline-kg__list"
        "mcp__pipeline-kg__context"
        "mcp__pipeline-kg__related"
        "mcp__pipeline-kg__impact"
        "mcp__pipeline-kg__coverage"
        "mcp__pipeline-kg__orphans"
        "mcp__pipeline-kg__usages"
        "mcp__pipeline-kg__path"
        "mcp__pipeline-kg__drift"
        "mcp__pipeline-kg__reindex"

        # ── MCP: OpenAPI ─────────────────────────────────────────────────
        "mcp__openapi__list_endpoints"
        "mcp__openapi__get_endpoint"
        "mcp__openapi__list_schemas"
        "mcp__openapi__get_schema"
        "mcp__openapi__info"
        "mcp__openapi__create"
        "mcp__openapi__validate"

        # ── MCP: Stack ───────────────────────────────────────────────────
        "mcp__stack__get"
        "mcp__stack__frontmatter"
        "mcp__stack__yaml_block"
        "mcp__stack__table"
        "mcp__stack__list"
        "mcp__stack__create"
        "mcp__stack__set"
        "mcp__stack__set_yaml_block"
        "mcp__stack__add_section"
        "mcp__stack__batch"
        "mcp__stack__validate"

        # ── MCP: Progress ────────────────────────────────────────────────
        "mcp__progress__read"
        "mcp__progress__set_phase_status"
        "mcp__progress__add_artifact"
        "mcp__progress__add_decision"
        "mcp__progress__add_waiver"
        "mcp__progress__add_pending"
        "mcp__progress__set_next_step"
        "mcp__progress__set_design_track"
        "mcp__progress__batch"
        "mcp__progress__validate"

        # ── MCP: Storybook ───────────────────────────────────────────────
        "mcp__storybook__preview-stories"
        "mcp__storybook__get-storybook-story-instructions"
        "mcp__storybook__list-all-documentation"
        "mcp__storybook__get-documentation"
        "mcp__storybook__get-documentation-for-story"
        "mcp__storybook__run-story-tests"

        # ── MCP: Playwright (wildcard — unsafe variant explicitly denied) ─
        "mcp__playwright__*"

        # ── MCP: Claude Preview ──────────────────────────────────────────
        "mcp__Claude_Preview__preview_screenshot"
        "mcp__Claude_Preview__preview_resize"
        "mcp__Claude_Preview__preview_console_logs"
        "mcp__Claude_Preview__preview_snapshot"
        "mcp__Claude_Preview__preview_inspect"
        "mcp__Claude_Preview__preview_logs"
        "mcp__Claude_Preview__preview_network"
        "mcp__Claude_Preview__preview_list"
        "mcp__Claude_Preview__preview_start"

        # ── MCP: Serena (code-symbol navigation + memory + editing) ──────
        # Read-only navigation:
        "mcp__serena__find_declaration"
        "mcp__serena__find_file"
        "mcp__serena__find_implementations"
        "mcp__serena__find_referencing_symbols"
        "mcp__serena__find_symbol"
        "mcp__serena__get_current_config"
        "mcp__serena__get_diagnostics_for_file"
        "mcp__serena__get_symbols_overview"
        "mcp__serena__initial_instructions"
        "mcp__serena__list_dir"
        "mcp__serena__list_memories"
        "mcp__serena__read_file"
        "mcp__serena__read_memory"
        "mcp__serena__search_for_pattern"
        # Editing (LSP-precise structural ops; same safety class as Edit/Write):
        "mcp__serena__insert_after_symbol"
        "mcp__serena__insert_before_symbol"
        "mcp__serena__replace_symbol_body"
        "mcp__serena__rename_symbol"
        "mcp__serena__safe_delete_symbol"
        "mcp__serena__replace_content"
        # Memory write/edit:
        "mcp__serena__write_memory"
        "mcp__serena__edit_memory"
        "mcp__serena__delete_memory"
        "mcp__serena__rename_memory"
        # Onboarding (writes initial memory):
        "mcp__serena__onboarding"

        # ── MCP: Vercel ──────────────────────────────────────────────────
        # Read-only listings + getters
        "mcp__vercel__list_projects"
        "mcp__vercel__list_deployments"
        "mcp__vercel__list_environments"
        "mcp__vercel__list_env_vars"
        "mcp__vercel__list_domains"
        "mcp__vercel__list_teams"
        "mcp__vercel__get_project"
        "mcp__vercel__get_deployment"
        "mcp__vercel__get_deployment_logs"
        "mcp__vercel__get_deployment_events"
        "mcp__vercel__get_env_var"
        "mcp__vercel__get_domain"
        "mcp__vercel__get_speed_insights"
        "mcp__vercel__get_web_analytics"
        # Auth (OAuth flow opens browser; not a destructive op)
        "mcp__vercel__authenticate"
        "mcp__vercel__complete_authentication"
      ];

      deny = [
        # ── Sensitive file paths (Edit) ──────────────────────────────────
        "Edit(~/.ssh/**)"
        "Edit(~/.aws/**)"
        "Edit(~/.gcp/**)"
        "Edit(~/.config/gcloud/**)"
        "Edit(~/.npmrc)"
        "Edit(~/.yarnrc)"
        "Edit(~/.bashrc)"
        "Edit(~/.zshrc)"
        "Edit(~/.profile)"
        "Edit(~/.bash_profile)"
        "Edit(~/.zprofile)"
        "Edit(~/.gitconfig)"
        "Edit(/etc/**)"

        # ── Sensitive file paths (Write) ─────────────────────────────────
        "Write(~/.ssh/**)"
        "Write(~/.aws/**)"
        "Write(~/.gcp/**)"
        "Write(~/.config/gcloud/**)"
        "Write(~/.npmrc)"
        "Write(~/.yarnrc)"
        "Write(~/.bashrc)"
        "Write(~/.zshrc)"
        "Write(~/.profile)"
        "Write(~/.bash_profile)"
        "Write(~/.zprofile)"
        "Write(~/.gitconfig)"
        "Write(/etc/**)"

        # ── Shell-pipe-execute (untrusted code from network) ─────────────
        "Bash(curl * | sh*)"
        "Bash(curl * | bash*)"
        "Bash(wget * | sh*)"
        "Bash(wget * | bash*)"
        "Bash(eval *)"

        # ── Privilege escalation (except darwin-rebuild allowed above) ───
        "Bash(sudo cat *)"
        "Bash(sudo cp *)"
        "Bash(sudo mv *)"
        "Bash(sudo rm *)"
        "Bash(sudo chmod *)"
        "Bash(sudo chown *)"

        # ── Catastrophic file deletion ───────────────────────────────────
        # Block only the patterns that cannot be legitimate. Patterns that
        # *could* hit a real project path (`rm -rf /Users/*`, `rm -rf ~/*`,
        # `rm -rf $HOME/*`) are intentionally NOT denied — the prompt
        # interception is preferable to a false-positive block on legitimate
        # project-internal rm-rf calls (e.g. `rm -rf <project>/build/`).
        "Bash(rm -rf /)"
        "Bash(rm -rf /*)"
        "Bash(rm -rf ~)"
        "Bash(rm -rf $HOME)"
        "Bash(rm -rf -- /*)"
        "Bash(rm -rf /System/*)"
        "Bash(rm -rf /Library/*)"
        "Bash(rm -rf /Applications/*)"

        # ── Permission destruction ───────────────────────────────────────
        "Bash(chmod 777 *)"
        "Bash(chmod -R 777 *)"
        "Bash(chown -R *)"

        # ── Disk / filesystem destruction ────────────────────────────────
        "Bash(dd if=* of=/dev/*)"
        "Bash(mkfs.*)"
        "Bash(mkfs *)"
        "Bash(fdisk *)"
        "Bash(diskutil eraseDisk *)"
        "Bash(diskutil eraseVolume *)"

        # ── Destructive git (history rewrites, hard reset) ──────────────
        # NOTE: push is intentionally NOT denied. Destructive push (--force / -f /
        # --delete) prompts for approval instead (per user: ask, don't block). Safe
        # push forms (normal + --force-with-lease) are allowed per-project in
        # settings.local.json; --force / --delete fall through to a prompt.
        "Bash(git reset --hard *)"
        "Bash(git reset --hard)"
        "Bash(git filter-branch *)"
        "Bash(git filter-repo *)"
        "Bash(git checkout --orphan *)"
        "Bash(git clean -fdx *)"
        "Bash(git clean -fdX *)"
        # `-C <path>` variants of the destructive set above — must mirror
        # because the broad `Bash(git -C *)` allow otherwise lets these
        # through against a different repo's path.
        "Bash(git -C * reset --hard *)"
        "Bash(git -C * reset --hard)"
        "Bash(git -C * filter-branch *)"
        "Bash(git -C * filter-repo *)"
        "Bash(git -C * checkout --orphan *)"
        "Bash(git -C * clean -fdx *)"
        "Bash(git -C * clean -fdX *)"

        # ── cp / mv from sensitive sources (paired with broad cp/mv allow) ──
        "Bash(cp ~/.ssh/* *)"
        "Bash(cp ~/.aws/* *)"
        "Bash(cp ~/.gcp/* *)"
        "Bash(cp ~/.config/gcloud/* *)"
        "Bash(cp /etc/* *)"
        "Bash(mv ~/.ssh/* *)"
        "Bash(mv ~/.aws/* *)"
        "Bash(mv ~/.gcp/* *)"
        "Bash(mv ~/.config/gcloud/* *)"
        "Bash(mv /etc/* *)"
        "Bash(mv ~/.gitconfig *)"

        # ── Accidental package publishing ────────────────────────────────
        "Bash(npm publish *)"
        "Bash(pnpm publish *)"
        "Bash(yarn publish *)"
        "Bash(npm publish)"
        "Bash(pnpm publish)"
        "Bash(yarn publish)"

        # ── MCP escape hatches that can execute arbitrary code ───────────
        "mcp__playwright__browser_run_code_unsafe"
        "mcp__serena__execute_shell_command"
        "mcp__Claude_in_Chrome__javascript_tool"
      ];
    };
    hooks = {
      Notification = [
        {
          matcher = "*";
          hooks = [
            {
              type = "command";
              command = "curl -d 'Claude needs your attention' https://ntfy.sh/$NTFY_TOPIC_ID";
              async = true;
              description = "Send notification when Claude needs attention";
            }
          ];
        }
      ];
      Stop = [
        {
          hooks = [
            {
              type = "command";
              command = "curl -d 'Claude is done!' https://ntfy.sh/$NTFY_TOPIC_ID";
              async = true;
              description = "Send notification when Claude finishes responding";
            }
          ];
        }
      ];
      PreToolUse = [
        {
          matcher = "Bash";
          hooks = [
            {
              type = "command";
              command = "rtk hook claude";
              description = "RTK token-killer proxy — rewrites Bash calls for token savings";
            }
            {
              type = "command";
              command = "bash $HOME/.claude/pipeline/scripts/hook-allow-safe-compound.sh 2>/dev/null || true";
              description = "Pipeline (optional): auto-approve compound commands (A|B, A&&B, A;B) whose every segment is allow-listed or a vetted read-only command, and none matches a deny rule; default-deny, no-op when pipeline not installed";
            }
          ];
        }
        {
          matcher = "";
          hooks = [
            {
              type = "command";
              command = "serena-hooks remind --client=claude-code";
              description = "Serena: general drift-prevention reminder before every tool use";
            }
          ];
        }
        {
          matcher = "mcp__serena__*";
          hooks = [
            {
              type = "command";
              command = "serena-hooks auto-approve --client=claude-code";
              description = "Serena: auto-approve safe Serena MCP tool calls";
            }
          ];
        }
      ];
      SessionStart = [
        {
          matcher = "";
          hooks = [
            {
              type = "command";
              command = "serena-hooks activate --client=claude-code";
              description = "Serena: prompt project activation at session start";
            }
          ];
        }
      ];
      SessionEnd = [
        {
          matcher = "";
          hooks = [
            {
              type = "command";
              command = "serena-hooks cleanup --client=claude-code";
              description = "Serena: cleanup on session end";
            }
          ];
        }
      ];
    };
    agentPushNotifEnabled = true;
  };
  };

  # Ensure uv-installed tools (serena-hooks, etc.) are on PATH for
  # Claude Code hook subshells (/bin/sh -c …) and login shells.
  home.sessionPath = [ "$HOME/.local/bin" ];
}
