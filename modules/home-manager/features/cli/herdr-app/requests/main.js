import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { spaces, run, exec, theme, shared, setShared, checking, home, layout } from "herdr";

const BLOCK = "requests";
const FOLDED_PX = 37;
function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

const POLL_MS = 60000;
const GLOBAL = "Global";
const FETCH = String.raw`cd "$1" 2>/dev/null || exit 3
u=$(git remote get-url origin 2>/dev/null) || exit 3
case "$u" in
*github.com*)
  me=$(gh api user --jq .login 2>/dev/null)
  def=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null)
  prs=$(gh pr list --limit 50 --json number,title,url,headRefName,baseRefName,isDraft,author,reviewRequests,reviewDecision,statusCheckRollup 2>/dev/null) || exit 4
  run=$(gh run list --branch "$def" --limit 1 --json databaseId,status,conclusion,url,updatedAt 2>/dev/null) || run='[]'
  failed='[]'
  if [ "$(printf '%s' "$run" | jq -r '.[0].conclusion // empty')" = failure ]; then
    failed=$(gh run view "$(printf '%s' "$run" | jq -r '.[0].databaseId')" --json jobs --jq '[.jobs[] | select(.conclusion == "failure") | {name, id: .databaseId}]' 2>/dev/null) || failed='[]'
  fi
  jq -nc --arg me "$me" --arg def "$def" --argjson prs "$prs" --argjson run "$run" --argjson failed "$failed" '
    def check_state: if (.conclusion // .state // "") | test("FAILURE|ERROR|TIMED_OUT|STARTUP_FAILURE"; "i") then "failed"
      elif (.status // "COMPLETED") != "COMPLETED" or (.state // "") == "PENDING" or (.state // "") == "EXPECTED" then "running"
      else "passed" end;
    {host: "github", me: $me,
     requests: [$prs[] | (.statusCheckRollup // []) as $c |
       ([$c[] | select(check_state == "failed")]) as $bad |
       {key: "#\(.number)", num: .number, title, url, source: .headRefName, target: .baseRefName, draft: .isDraft,
        author: .author.login, mine: (.author.login == $me), review: ([.reviewRequests[]?.login] | index($me) != null),
        approved: (.reviewDecision == "APPROVED"),
        ci: {state: (if ($c | length) == 0 then "none" elif ($bad | length) > 0 then "failed" elif any($c[]; check_state == "running") then "running" else "passed" end),
             at: ([$c[] | .completedAt // .startedAt // empty | select(startswith("0001") | not)] | max),
             failed: [$bad[] | {name: (.name // .context), id: ((.detailsUrl // .targetUrl // "") | capture("/job/(?<j>[0-9]+)").j // null)}],
             url: (($bad[0].detailsUrl // $bad[0].targetUrl) // "\(.url)/checks")}}],
     default: ($run[0] // null | if . == null then null else
       {branch: $def, state: (if .status != "completed" then "running" elif .conclusion == "success" then "passed" elif .conclusion == "failure" then "failed" else (.conclusion // "none") end),
        at: .updatedAt, url, run: .databaseId, failed: $failed} end)}'
  ;;
*)
  me=$(glab api user 2>/dev/null | jq -r .username)
  proj=$(glab api projects/:id 2>/dev/null) || exit 4
  id=$(printf '%s' "$proj" | jq -r .id)
  def=$(printf '%s' "$proj" | jq -r .default_branch)
  mrs=$(glab api "projects/$id/merge_requests?state=opened&per_page=50" 2>/dev/null) || exit 4
  pipes=$(glab api "projects/$id/pipelines?per_page=100" 2>/dev/null) || pipes='[]'
  latest=$(jq -nc --argjson mrs "$mrs" --argjson pipes "$pipes" --arg def "$def" '
    [($def), ($mrs[] | .source_branch, "refs/merge-requests/\(.iid)/head")] as $refs |
    [$pipes[] | select(.ref as $r | $refs | index($r))] | group_by(.ref) | map(max_by(.id))')
  jobs='{}'
  for pid in $(printf '%s' "$latest" | jq -r '.[] | select(.status == "failed") | .id' | head -15); do
    j=$(glab api "projects/$id/pipelines/$pid/jobs?scope[]=failed&per_page=10" 2>/dev/null) || continue
    jobs=$(jq -nc --argjson acc "$jobs" --argjson j "$j" --arg pid "$pid" '$acc + {($pid): [$j[] | {name, id: (.id | tostring)}]}')
  done
  jq -nc --arg me "$me" --arg def "$def" --argjson mrs "$mrs" --argjson latest "$latest" --argjson jobs "$jobs" '
    def state: if . == null then "none" elif .status == "success" then "passed" elif .status == "failed" then "failed"
      elif (.status | test("running|pending|created|preparing|waiting_for_resource|scheduled")) then "running" else .status end;
    def ci(p): {state: (p | state), at: (p.updated_at // null), url: (p.web_url // null), pipeline: (p.id // null), failed: ($jobs[(p.id // 0) | tostring] // [])};
    {host: "gitlab", me: $me,
     requests: [$mrs[] | .iid as $iid | .source_branch as $b |
       ([$latest[] | select(.ref == $b or .ref == "refs/merge-requests/\($iid)/head")] | max_by(.id)) as $p |
       {key: "!\(.iid)", num: .iid, title, url: .web_url, source: .source_branch, target: .target_branch, draft: (.draft // .work_in_progress),
        author: .author.username, mine: (.author.username == $me), review: ([.reviewers[]?.username] | index($me) != null),
        approved: (if .detailed_merge_status == "not_approved" then false else null end), ci: ci($p)}],
     default: ([$latest[] | select(.ref == $def)][0] as $p | if $p == null then null else ci($p) + {branch: $def} end)}'
  ;;
esac`;

const quote = (s) => `'${String(s).replace(/'/g, `'\\''`)}'`;

function ago(at) {
  const t = at ? Date.parse(at) : NaN;
  if (Number.isNaN(t)) return "";
  const m = Math.max(0, Math.round((Date.now() - t) / 60000));
  return m < 60 ? `${m}m` : m < 1440 ? `${Math.floor(m / 60)}h` : `${Math.floor(m / 1440)}d`;
}

function stacked(reqs) {
  const bySource = new Map(reqs.map((r) => [r.source, r]));
  const kids = new Map();
  const roots = [];
  for (const r of reqs) {
    const parent = bySource.get(r.target);
    if (parent && parent !== r) {
      if (!kids.has(parent.url)) kids.set(parent.url, []);
      kids.get(parent.url).push(r);
    } else roots.push(r);
  }
  const out = [];
  const seen = new Set();
  const walk = (r, depth) => {
    if (seen.has(r.url)) return;
    seen.add(r.url);
    out.push({ r, depth });
    for (const k of (kids.get(r.url) ?? []).sort((a, b) => a.num - b.num)) walk(k, depth + 1);
  };
  const weight = (r) => (r.review ? 2 : 0) + (r.mine ? 1 : 0);
  roots.sort((a, b) => weight(b) - weight(a) || b.num - a.num).forEach((r) => walk(r, 0));
  for (const r of reqs) walk(r, 0);
  return out;
}

export default class Requests extends View {
  init(_props, cx) {
    this.data = {};
    this.folded = new Set(shared("requests.folded") ?? []);
    this.creating = 0;
    this.polling = false;
    if (checking()) return;
    this.ensureGlobal();
    cx.timer.every(POLL_MS, (cx) => this.poll(cx));
    cx.timer.after(2500, (cx) => this.poll(cx));
  }

  ensureGlobal() {
    const list = spaces();
    const known = shared("requests.global");
    if (known && list.some((s) => s.id === known)) return known;
    const found = list.find((s) => !s.machine && s.name === GLOBAL);
    if (found) {
      setShared("requests.global", found.id);
      return found.id;
    }
    if (Date.now() - this.creating > 10000) {
      this.creating = Date.now();
      run("space.new", { name: GLOBAL, folder: home(), machine: "", focus: false });
    }
    return null;
  }

  repos() {
    const global = shared("requests.global");
    const out = new Map();
    for (const [id, r] of Object.entries(shared("space.repos") ?? {})) {
      if (id === global || !r?.path) continue;
      const key = JSON.stringify([r.machine ?? null, r.path]);
      if (!out.has(key)) out.set(key, { key, name: r.name, machine: r.machine ?? null, path: r.path });
    }
    return [...out.values()].sort((a, b) => String(a.machine ?? "").localeCompare(String(b.machine ?? "")) || a.name.localeCompare(b.name));
  }

  poll(cx) {
    if (this.polling) return;
    this.polling = true;
    const repos = this.repos();
    cx.spawn(async (cx) => {
      for (const repo of repos) {
        try {
          const r = await exec("sh", ["-c", FETCH, "requests", repo.path], { on: repo.machine, timeout: 45000 });
          if (r.code === 0) {
            const next = { ...JSON.parse(r.stdout), at: Date.now(), error: null };
            this.alert(repo, this.data[repo.key], next);
            this.data[repo.key] = next;
          } else if (r.code !== 3) {
            this.data[repo.key] = { ...(this.data[repo.key] ?? {}), error: (r.stderr || `exit ${r.code}`).trim().split("\n").pop() };
          }
        } catch (e) {
          this.data[repo.key] = { ...(this.data[repo.key] ?? {}), error: String(e?.message ?? e) };
        }
        cx.notify();
      }
      this.polling = false;
      cx.notify();
    });
  }

  alert(repo, before, now) {
    if (!before?.requests) return;
    const was = new Map(before.requests.map((r) => [r.url, r]));
    const say = (subtitle, message, url) =>
      exec("terminal-notifier", ["-title", repo.name, "-subtitle", subtitle, "-message", message, "-group", `herdr-req-${url}`, "-open", url]).catch(() => {});
    for (const r of now.requests ?? []) {
      const old = was.get(r.url);
      if (r.review && !old?.review) say("Review requested", `${r.key} ${r.title}`, r.url);
      if (r.mine && r.ci?.state === "failed" && old && old.ci?.state !== "failed") say(`CI failed on ${r.key}`, r.ci.failed?.map((j) => j.name).join(", ") || r.title, r.ci.url ?? r.url);
    }
    const d = now.default;
    if (d?.state === "failed" && before.default?.state !== "failed" && d.url) say(`CI failed on ${d.branch}`, d.failed?.map((j) => j.name).join(", ") || "pipeline failed", d.url);
  }

  openTab(name, folder, argv) {
    const global = this.ensureGlobal();
    const space = global && spaces().find((s) => s.id === global);
    if (!space) return;
    const tab = space.tabs.find((t) => t.name === name);
    if (tab) {
      run("space.select", { id: global });
      run("tab.select", { id: tab.id });
      return;
    }
    run("tab.new", { space: global, name, folder, argv });
  }

  where(repo, argv) {
    if (!repo.machine) return { folder: repo.path, argv };
    return { folder: home(), argv: ["ssh", "-t", repo.machine, `cd ${quote(repo.path)} && exec ${argv.map(quote).join(" ")}`] };
  }

  openRequest(repo, r) {
    const name = `${r.key} · ${r.title}`.slice(0, 70);
    const w = this.where(repo, ["tuicr", "pr", r.url]);
    this.openTab(name, w.folder, w.argv);
  }

  openCi(repo, host, branch, ci) {
    const job = ci.failed?.find((j) => j.id)?.id;
    if (ci.state !== "failed" || !job) {
      if (ci.url) exec("/usr/bin/open", [ci.url]).catch(() => {});
      return;
    }
    const log = host === "github" ? `gh run view --job ${job} --log-failed | less -R` : `glab ci trace ${job} | less -R`;
    const w = this.where(repo, ["sh", "-c", log]);
    this.openTab(`CI · ${repo.name} · ${branch}`.slice(0, 70), w.folder, w.argv);
  }

  fold(id, cx) {
    this.folded.has(id) ? this.folded.delete(id) : this.folded.add(id);
    setShared("requests.folded", [...this.folded]);
    cx.notify();
  }

  toggleSection(cx) {
    const folded = !this.folded.has(BLOCK);
    if (folded) {
      const w = find(layout(), BLOCK)?.size?.weight;
      if (w) setShared("requests.weight", w);
    }
    this.fold(BLOCK, cx);
    run("layout.resize", folded ? { id: BLOCK, px: FOLDED_PX } : { id: BLOCK, weight: shared("requests.weight") ?? 1 });
  }

  tally(t, live) {
    const requests = live.reduce((n, x) => n + (x.d.requests?.length ?? 0), 0);
    const states = live.flatMap(({ d }) => [d.default, ...(d.requests ?? []).map((r) => r.ci)])
      .filter((c) => c && c.state && c.state !== "none").map((c) => c.state);
    const count = (s) => states.filter((x) => x === s).length;
    const failed = count("failed");
    const running = count("running");
    const ci = failed ? [`✗ ${failed}`, t.blocked, `${failed} failing`]
      : running ? [`● ${running}`, t.working, `${running} running`]
      : states.length ? [`✓ ${count("passed")}`, t.done, `${count("passed")} passing`] : null;
    return { requests, ci };
  }

  ciIcon(t, state) {
    if (state === "running") return svg("mods/workspace-chrome/spinner.svg").size(11).flex_none().text_color(t.working);
    const [mark, color] = state === "passed" ? ["✓", t.done] : state === "failed" ? ["✗", t.blocked] : state === "manual" ? ["▷", t.dim] : ["·", t.dim];
    return div().w(11).flex_none().text_size(11).text_color(color).child(mark);
  }

  header(t, id, label, count, top) {
    const open = !this.folded.has(id);
    return h_flex().id(id).px(8).h(top ? 28 : 24).flex_none().gap(6).items_center()
      .text_size(top ? 11 : 10.5).font_medium().cursor_pointer().text_color(top ? t.dim : t.muted)
      .hover((s) => s.text_color(t.foreground))
      .on_click((_e, cx) => this.fold(id, cx))
      .child(svg(`mods/workspace-chrome/chevron-${open ? "down" : "right"}.svg`).size(10).flex_none())
      .child(div().truncate().child(label))
      .when(count != null, (el) => el.child(div().text_color(t.dim).child(String(count))));
  }

  requestRow(t, repo, r, depth) {
    return h_flex().id(`rq-${r.url}`).pl(18 + depth * 12).pr(8).h(24).flex_none().gap(6).items_center().rounded(5)
      .cursor_pointer().hover((s) => s.bg(t.hover))
      .tooltip(`${r.source} → ${r.target} · @${r.author}${r.draft ? " · draft" : ""}. Click: review in tuicr (Global space)`)
      .on_click(() => this.openRequest(repo, r))
      .when(depth > 0, (el) => el.child(div().text_size(10).text_color(t.dim).child("└")))
      .child(this.ciIcon(t, r.ci?.state))
      .child(div().flex_none().text_size(11).text_color(r.mine ? t.accent : t.dim).child(r.key))
      .child(div().flex_1().min_w(0).truncate().text_size(12).text_color(r.draft ? t.dim : t.foreground).child(r.title))
      .when(r.review, (el) => el.child(div().flex_none().text_size(10).text_color(t.blocked).child("review")))
      .when(r.approved === true, (el) => el.child(div().flex_none().text_size(10).text_color(t.done).child("✓")));
  }

  ciRow(t, repo, host, branch, ci, id) {
    const failed = ci.state === "failed" ? (ci.failed ?? []).map((j) => j.name).join(", ") : "";
    return v_flex().id(id).pl(18).pr(8).py(3).flex_none().rounded(5).cursor_pointer().hover((s) => s.bg(t.hover))
      .tooltip(ci.state === "failed" ? "Click: the failed job's log in the Global space" : "Click: open the pipeline")
      .on_click(() => this.openCi(repo, host, branch, ci))
      .child(h_flex().gap(6).items_center()
        .child(this.ciIcon(t, ci.state))
        .child(div().flex_1().min_w(0).truncate().text_size(12).text_color(t.foreground).child(branch))
        .child(div().flex_none().text_size(10.5).text_color(t.dim).child(ago(ci.at))))
      .when(Boolean(failed), (el) => el.child(div().pl(17).truncate().text_size(10.5).text_color(t.blocked).child(failed)));
  }

  render() {
    const t = theme();
    if (!checking()) this.ensureGlobal();
    const repos = this.repos();
    const live = repos.map((repo) => ({ repo, d: this.data[repo.key] })).filter((x) => x.d);
    const total = live.reduce((n, x) => n + (x.d.requests?.length ?? 0), 0);
    const rows = [];

    rows.push(this.header(t, "rq-sec-requests", "Requests", total, true));
    if (!this.folded.has("rq-sec-requests")) {
      for (const { repo, d } of live) {
        const reqs = d.requests ?? [];
        if (!reqs.length && !d.error) continue;
        const id = `rq-repo-${repo.key}`;
        rows.push(this.header(t, id, repo.machine ? `${repo.name} · ${repo.machine}` : repo.name, reqs.length, false));
        if (this.folded.has(id)) continue;
        if (d.error) rows.push(div().pl(18).pr(8).py(2).text_size(11).text_color(t.blocked).truncate().child(d.error));
        for (const { r, depth } of stacked(reqs)) rows.push(this.requestRow(t, repo, r, depth));
      }
    }

    const sum = this.tally(t, live);
    rows.push(this.header(t, "rq-sec-ci", "CI", sum.ci ? sum.ci[0] : null, true));
    if (!this.folded.has("rq-sec-ci")) {
      for (const { repo, d } of live) {
        const branches = [];
        if (d.default) branches.push([d.default.branch, d.default]);
        for (const r of d.requests ?? []) if (r.ci && r.ci.state !== "none") branches.push([r.source, r.ci]);
        if (!branches.length) continue;
        const id = `ci-repo-${repo.key}`;
        const bad = branches.filter(([, c]) => c.state === "failed").length;
        rows.push(this.header(t, id, repo.machine ? `${repo.name} · ${repo.machine}` : repo.name, bad ? `${bad} ✗` : null, false));
        if (this.folded.has(id)) continue;
        branches.forEach(([branch, ci], i) => rows.push(this.ciRow(t, repo, d.host, branch, ci, `ci-${repo.key}-${i}`)));
      }
    }

    const shut = this.folded.has(BLOCK);
    return v_flex().size_full().min_h(0).bg(t.chrome).border_t(1).border_color(t.border).text_size(13)
      .child(h_flex().px(16).h(36).pt(10).flex_none().items_center().justify_between()
        .child(h_flex().id("rq-section").gap(6).items_center().cursor_pointer().text_size(11.5).font_medium().text_color(t.dim)
          .hover((s) => s.text_color(t.foreground))
          .tooltip(shut ? "Show requests and CI" : "Fold requests and CI")
          .on_click((_e, cx) => this.toggleSection(cx))
          .child(svg(`mods/workspace-chrome/chevron-${shut ? "right" : "down"}.svg`).size(10).flex_none())
          .child("Requests & CI")
          .when(live.length > 0, (el) => el
            .child(div().id("rq-count").text_color(t.muted).tooltip(`${sum.requests} open requests`).child(String(sum.requests)))
            .when(Boolean(sum.ci), (el) => el.child(div().id("ci-count").text_color(sum.ci[1]).tooltip(`CI: ${sum.ci[2]}`).child(sum.ci[0])))))
        .child(div().id("rq-refresh").text_size(12).text_color(t.dim).cursor_pointer()
          .hover((s) => s.text_color(t.foreground)).tooltip("Look again now")
          .on_click((_e, cx) => this.poll(cx))
          .child(this.polling ? "…" : "↻")))
      .when(!shut && !repos.length, (el) => el.child(div().px(16).py(4).text_size(12).text_color(t.dim)
        .child("No space is open in a repository yet.")))
      .when(!shut && repos.length > 0 && !live.length, (el) => el.child(div().px(16).py(4).text_size(12).text_color(t.dim)
        .child("Looking up requests…")))
      .when(!shut, (el) => el.child(v_flex().id("rq-list").flex_1().min_h(0).px(8).pb(6).overflow_y_scrollbar().children(rows)));
  }
}
