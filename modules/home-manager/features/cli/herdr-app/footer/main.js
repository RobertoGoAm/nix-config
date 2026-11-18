import { View, div, svg } from "gpui-kit";
import { h_flex, v_flex } from "gpui-base";
import { theme, run, updates, layout } from "herdr";

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

const narrow = () => (find(layout(), "sidebar")?.size?.px ?? Infinity) < 160;

export default class Footer extends View {
  render() {
    const t = theme();
    const collapsed = narrow();
    const ready = div().size(6).rounded_full().bg(t.accent);
    const settings = h_flex().id("settings").h(28).px(8).gap(9).items_center().rounded(8)
      .when(collapsed, (el) => el.relative().w(32).px(0).justify_center().tooltip("Settings"))
      .text_color(t.muted).hover((s) => s.bg(t.hover).text_color(t.foreground)).cursor_pointer()
      .on_click(() => run("app.settings")).child(svg("mods/workspace-chrome/settings.svg").size(14))
      .when(!collapsed, (el) => el.child("Settings"))
      .when(Boolean(updates()?.app?.ready), (el) => el.child(collapsed ? ready.absolute().top(5).right(6) : ready));
    return v_flex().size_full().bg(t.chrome).border_t(1).border_color(t.border).px(8).pt(4).pb(8).text_size(13)
      .when(collapsed, (el) => el.px(0).items_center())
      .child(settings);
  }
}
