// Rann admin portal: log in, dashboard, users and players (fighters).
// Talks to /admin/api on the same server. Plain JavaScript, no build step.
"use strict";

const TOKEN_KEY = "rann_admin_token";
const $ = (id) => document.getElementById(id);

// ---- Small helpers ---------------------------------------------------------

/** Builds an element. Text always goes in as text, never as HTML. */
function el(tag, attrs = {}, ...children) {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(attrs)) {
    if (key === "class") node.className = value;
    else if (key.startsWith("on")) node.addEventListener(key.slice(2), value);
    else node.setAttribute(key, value);
  }
  for (const child of children.flat()) {
    if (child !== null && child !== undefined) node.append(child instanceof Node ? child : String(child));
  }
  return node;
}

const SVG = "http://www.w3.org/2000/svg";
function svg(tag, attrs = {}) {
  const node = document.createElementNS(SVG, tag);
  for (const [key, value] of Object.entries(attrs)) node.setAttribute(key, value);
  return node;
}

const number = (n) => Number(n).toLocaleString();
const shortDay = (iso) => new Date(iso + "T00:00:00").toLocaleDateString(undefined, { day: "numeric", month: "short" });
const date = (iso) => new Date(iso).toLocaleDateString(undefined, { day: "numeric", month: "short", year: "numeric" });

let toastTimer;
function toast(message, bad = false) {
  const t = $("toast");
  t.textContent = message;
  t.className = bad ? "toast bad" : "toast";
  t.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => (t.hidden = true), 3500);
}

// ---- The API ---------------------------------------------------------------

function token() {
  try { return sessionStorage.getItem(TOKEN_KEY) || ""; } catch { return ""; }
}
function setToken(value) {
  try {
    if (value) sessionStorage.setItem(TOKEN_KEY, value);
    else sessionStorage.removeItem(TOKEN_KEY);
  } catch { /* private mode: the login lasts until the page reloads */ }
  memoryToken = value;
}
let memoryToken = token();

/** Calls the admin API. A 401 (expired or no login) goes back to the login screen. */
async function api(method, path, body) {
  const headers = {};
  if (memoryToken) headers.Authorization = `Bearer ${memoryToken}`;
  if (body !== undefined) headers["Content-Type"] = "application/json";
  let res;
  try {
    res = await fetch(`/admin/api${path}`, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  } catch {
    throw new Error("Can't reach the server. Is it running?");
  }
  const data = await res.json().catch(() => ({}));
  if (res.status === 401 && path !== "/login") {
    logOut("Please log in again.");
    throw new Error("Please log in again.");
  }
  if (!res.ok) throw new Error(data.message || `Something went wrong (${res.status}).`);
  return data;
}

// ---- Log in / out ----------------------------------------------------------

$("login-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  const error = $("login-error");
  const button = form.querySelector("button");
  error.hidden = true;
  const email = form.email.value.trim();
  const password = form.password.value;
  if (!email || !password) {
    error.textContent = "Enter your email and password.";
    error.hidden = false;
    return;
  }
  button.disabled = true;
  button.textContent = "Logging in…";
  try {
    const data = await api("POST", "/login", { email, password });
    setToken(data.token);
    form.password.value = "";
    showPortal(data.email);
  } catch (err) {
    error.textContent = err.message;
    error.hidden = false;
  } finally {
    button.disabled = false;
    button.textContent = "Log in";
  }
});

function logOut(message) {
  setToken("");
  $("portal").hidden = true;
  $("login").hidden = false;
  closeMenu();
  if (message) {
    $("login-error").textContent = message;
    $("login-error").hidden = false;
  }
  $("login-form").email.focus();
}
$("logout").addEventListener("click", () => {
  logOut();
  location.hash = "";
});

function showPortal(email) {
  $("admin-email").textContent = email;
  $("login").hidden = true;
  $("portal").hidden = false;
  route();
}

// ---- The top-right menu ----------------------------------------------------

function closeMenu() {
  $("menu-list").hidden = true;
  $("menu-button").setAttribute("aria-expanded", "false");
}
$("menu-button").addEventListener("click", (event) => {
  event.stopPropagation();
  const open = $("menu-list").hidden;
  $("menu-list").hidden = !open;
  $("menu-button").setAttribute("aria-expanded", String(open));
});
document.addEventListener("click", (event) => {
  if (!$("menu-list").contains(event.target)) closeMenu();
});
document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") closeMenu();
});

// ---- Pages -----------------------------------------------------------------

const PAGES = { dashboard: loadDashboard, users: loadUsers, players: loadPlayers };

function route() {
  if ($("portal").hidden) return;
  const name = location.hash.replace(/^#\//, "") || "dashboard";
  const page = PAGES[name] ? name : "dashboard";
  for (const key of Object.keys(PAGES)) $(`page-${key}`).hidden = key !== page;
  for (const link of document.querySelectorAll(".menu-list a")) {
    if (link.getAttribute("href") === `#/${page}`) link.setAttribute("aria-current", "page");
    else link.removeAttribute("aria-current");
  }
  closeMenu();
  PAGES[page]().catch((err) => toast(err.message, true));
}
window.addEventListener("hashchange", route);

// ---- Dashboard -------------------------------------------------------------

async function loadDashboard() {
  const stats = await api("GET", "/stats");
  const u = stats.users;
  const m = stats.matches;
  const tile = (label, value, note) =>
    el("div", { class: "tile" }, el("div", { class: "label" }, label), el("div", { class: "value" }, number(value)), note ? el("div", { class: "note" }, note) : null);
  $("tiles").replaceChildren(
    tile("Users", u.total, `${number(u.verified)} verified`),
    tile("Active users", u.active),
    tile("Inactive users", u.inactive, `${number(u.disabled)} switched off by admin`),
    tile("New this week", u.new_7d, `${number(u.new_30d)} in 30 days`),
    tile("Ranked matches", m.total, `${number(m.confirmed)} finished · ${number(m.disputed)} disputed`),
    tile("Matches this week", m.last_7d),
  );
  columnChart($("chart-signups"), "Sign-ups per day", "Last 30 days", stats.signups_per_day, "sign-ups");
  columnChart($("chart-matches"), "Ranked matches per day", "Last 30 days", stats.matches_per_day, "matches");
  columnChart($("chart-players"), "Players online per day", "Players who logged in or played, last 30 days", stats.players_per_day, "players");
  barChart($("chart-picks"), "Fighter picks", "In ranked matches", stats.fighter_picks);

  if (stats.top_players.length === 0) {
    $("top-players").replaceChildren(el("p", { class: "empty" }, "No ranked games yet."));
  } else {
    $("top-players").replaceChildren(
      el("table", {},
        el("thead", {}, el("tr", {}, el("th", {}, "#"), el("th", {}, "Player"), el("th", { class: "num" }, "Rating"),
          el("th", { class: "num" }, "Games"), el("th", { class: "num" }, "Won"), el("th", { class: "num" }, "Lost"))),
        el("tbody", {}, stats.top_players.map((p, i) =>
          el("tr", {}, el("td", {}, i + 1), el("td", {}, p.username), el("td", { class: "num" }, p.rating),
            el("td", { class: "num" }, p.games_played), el("td", { class: "num" }, p.wins), el("td", { class: "num" }, p.losses))))),
    );
  }
}

const tooltip = $("tooltip");
function showTip(event, text) {
  tooltip.textContent = text;
  tooltip.hidden = false;
  const x = Math.min(event.clientX + 12, window.innerWidth - tooltip.offsetWidth - 8);
  tooltip.style.left = `${x}px`;
  tooltip.style.top = `${event.clientY - 36}px`;
}
const hideTip = () => (tooltip.hidden = true);

/** A "nice" top for the y-axis, and its tick step. */
function niceScale(max) {
  if (max <= 4) return { top: Math.max(max, 1), step: 1 };
  const rough = max / 4;
  const power = 10 ** Math.floor(Math.log10(rough));
  const step = [1, 2, 5, 10].map((f) => f * power).find((s) => s >= rough);
  return { top: Math.ceil(max / step) * step, step };
}

function chartFrame(figure, title, subtitle, total) {
  figure.replaceChildren(
    el("h3", {}, title),
    el("p", { class: "total" }, total === undefined ? subtitle : `${subtitle} · ${number(total)} total`),
  );
}

function tableView(headers, rows) {
  return el("details", {},
    el("summary", {}, "Show as table"),
    el("table", {}, el("thead", {}, el("tr", {}, headers.map((h, i) => el("th", { class: i ? "num" : "" }, h)))),
      el("tbody", {}, rows.map((r) => el("tr", {}, r.map((c, i) => el("td", { class: i ? "num" : "" }, c)))))));
}

/** Columns, one per day. */
function columnChart(figure, title, subtitle, series, unit) {
  const total = series.reduce((sum, d) => sum + d.count, 0);
  chartFrame(figure, title, subtitle, total);
  const W = 560, H = 200, left = 32, right = 8, top = 10, bottom = 24;
  const plotW = W - left - right, plotH = H - top - bottom;
  const { top: yTop, step } = niceScale(Math.max(...series.map((d) => d.count)));
  const chart = svg("svg", { viewBox: `0 0 ${W} ${H}`, role: "img", "aria-label": `${title}: ${number(total)} ${unit} in the last 30 days` });
  for (let v = 0; v <= yTop; v += step) {
    const y = top + plotH - (v / yTop) * plotH;
    if (v > 0) chart.append(svg("line", { class: "gridline", x1: left, x2: W - right, y1: y, y2: y }));
    const label = svg("text", { class: "axis", x: left - 6, y: y + 4, "text-anchor": "end" });
    label.textContent = number(v);
    chart.append(label);
  }
  const slot = plotW / series.length;
  const barW = Math.min(14, slot - 2);
  series.forEach((d, i) => {
    const x = left + i * slot + (slot - barW) / 2;
    const h = (d.count / yTop) * plotH;
    const g = svg("g");
    const hit = svg("rect", { class: "hit", x: left + i * slot, y: top, width: slot, height: plotH });
    g.append(hit);
    if (h > 0) {
      const r = Math.min(4, barW / 2, h);
      const y = top + plotH - h, b = top + plotH;
      g.append(svg("path", {
        class: "bar",
        d: `M${x},${b} V${y + r} Q${x},${y} ${x + r},${y} H${x + barW - r} Q${x + barW},${y} ${x + barW},${y + r} V${b} Z`,
      }));
    }
    const text = `${shortDay(d.day)}: ${number(d.count)} ${unit}`;
    hit.addEventListener("mousemove", (e) => { g.classList.add("on"); showTip(e, text); });
    hit.addEventListener("mouseleave", () => { g.classList.remove("on"); hideTip(); });
    chart.append(g);
    if ((i % 7 === 0 && i < series.length - 4) || i === series.length - 1) {
      const label = svg("text", { class: "axis", x: left + i * slot + slot / 2, y: H - 6, "text-anchor": "middle" });
      label.textContent = shortDay(d.day);
      chart.append(label);
    }
  });
  chart.append(svg("line", { class: "baseline", x1: left, x2: W - right, y1: top + plotH, y2: top + plotH }));
  figure.append(chart, tableView(["Day", unit[0].toUpperCase() + unit.slice(1)], series.map((d) => [shortDay(d.day), number(d.count)])));
}

/** Horizontal bars, biggest first, with the number at the end of each bar. */
function barChart(figure, title, subtitle, rows) {
  chartFrame(figure, title, subtitle);
  if (rows.length === 0) {
    figure.append(el("p", { class: "empty" }, "No ranked matches yet."));
    return;
  }
  const W = 560, labelW = 120, valueW = 48, rowH = 30, barH = 18;
  const H = rows.length * rowH;
  const max = Math.max(...rows.map((r) => r.picks));
  const plotW = W - labelW - valueW;
  const all = rows.reduce((sum, r) => sum + r.picks, 0);
  const chart = svg("svg", { viewBox: `0 0 ${W} ${H}`, role: "img", "aria-label": `${title}: ` + rows.map((r) => `${r.fighter} ${r.picks}`).join(", ") });
  rows.forEach((r, i) => {
    const y = i * rowH + (rowH - barH) / 2;
    const w = Math.max(2, (r.picks / max) * plotW);
    const g = svg("g");
    const name = svg("text", { class: "axis", x: labelW - 8, y: y + barH / 2 + 4, "text-anchor": "end" });
    name.textContent = r.fighter;
    const radius = Math.min(4, w / 2);
    const bar = svg("path", {
      class: "bar",
      d: `M${labelW},${y} H${labelW + w - radius} Q${labelW + w},${y} ${labelW + w},${y + radius} V${y + barH - radius} Q${labelW + w},${y + barH} ${labelW + w - radius},${y + barH} H${labelW} Z`,
    });
    const value = svg("text", { class: "value-label", x: labelW + w + 6, y: y + barH / 2 + 4 });
    value.textContent = number(r.picks);
    const hit = svg("rect", { class: "hit", x: 0, y: i * rowH, width: W, height: rowH });
    const text = `${r.fighter}: ${number(r.picks)} picks (${Math.round((r.picks / all) * 100)}%)`;
    hit.addEventListener("mousemove", (e) => { g.classList.add("on"); showTip(e, text); });
    hit.addEventListener("mouseleave", () => { g.classList.remove("on"); hideTip(); });
    g.append(name, bar, value, hit);
    chart.append(g);
  });
  chart.append(svg("line", { class: "baseline", x1: labelW, x2: labelW, y1: 0, y2: H }));
  figure.append(chart, tableView(["Fighter", "Picks"], rows.map((r) => [r.fighter, number(r.picks)])));
}

// ---- Users -----------------------------------------------------------------

const usersView = { status: "active", q: "", page: 1, pages: 1 };

for (const tab of document.querySelectorAll("#page-users [data-status]")) {
  tab.addEventListener("click", () => {
    usersView.status = tab.dataset.status;
    usersView.page = 1;
    loadUsers().catch((err) => toast(err.message, true));
  });
}
let searchTimer;
$("user-search").addEventListener("input", (event) => {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(() => {
    usersView.q = event.target.value.trim();
    usersView.page = 1;
    loadUsers().catch((err) => toast(err.message, true));
  }, 250);
});
$("prev-page").addEventListener("click", () => { usersView.page--; loadUsers().catch((err) => toast(err.message, true)); });
$("next-page").addEventListener("click", () => { usersView.page++; loadUsers().catch((err) => toast(err.message, true)); });

const STATUS = {
  active: ["Active", "good"],
  deactivated: ["Deactivated by player", "neutral"],
  disabled: ["Switched off by admin", "bad"],
};

async function loadUsers() {
  for (const tab of document.querySelectorAll("#page-users [data-status]")) {
    tab.setAttribute("aria-selected", String(tab.dataset.status === usersView.status));
  }
  const params = new URLSearchParams({ status: usersView.status, q: usersView.q, page: String(usersView.page) });
  const data = await api("GET", `/users?${params}`);
  usersView.pages = Math.max(1, Math.ceil(data.total / data.page_size));
  const from = data.total === 0 ? 0 : (data.page - 1) * data.page_size + 1;
  const to = Math.min(data.total, data.page * data.page_size);
  $("users-summary").textContent = data.total === 0
    ? (usersView.q ? "No users match that search." : `No ${usersView.status} users.`)
    : `${number(from)}–${number(to)} of ${number(data.total)} ${usersView.status} users`;
  $("prev-page").disabled = data.page <= 1;
  $("next-page").disabled = data.page >= usersView.pages;

  if (data.users.length === 0) {
    $("users-list").replaceChildren();
    return;
  }
  const cell = (label, content, cls = "") => el("td", { "data-label": label, class: cls }, content);
  $("users-list").replaceChildren(
    el("table", { class: "users-table" },
      el("thead", {}, el("tr", {}, ["Username", "Email", "Verified", "Rating", "Games", "Joined", "Status", ""].map((h, i) =>
        el("th", { class: i === 3 || i === 4 ? "num" : "" }, h)))),
      el("tbody", {}, data.users.map((u) => {
        const [label, tone] = STATUS[u.status];
        const action = u.status === "active"
          ? el("button", { type: "button", class: "danger", onclick: () => setUser(u, false) }, "Switch off")
          : el("button", { type: "button", onclick: () => setUser(u, true) }, "Switch on");
        return el("tr", {},
          cell("Username", u.username),
          cell("Email", u.email),
          cell("Verified", u.email_verified ? "Yes" : "No"),
          cell("Rating", u.rating, "num"),
          cell("Games", u.games_played, "num"),
          cell("Joined", date(u.joined)),
          cell("Status", el("span", { class: `badge ${tone}` }, label)),
          cell("", action));
      }))),
  );
}

async function setUser(user, on) {
  const question = on
    ? `Switch ${user.username} back on? They can log in and play again.`
    : `Switch ${user.username} off? They're logged out on every device and can't log in until you switch them back on.`;
  if (!confirm(question)) return;
  try {
    await api("POST", `/users/${user.id}/${on ? "enable" : "disable"}`, {});
    toast(on ? `${user.username} is switched on.` : `${user.username} is switched off.`);
    await loadUsers();
  } catch (err) {
    toast(err.message, true);
  }
}

// ---- Players (fighters) ----------------------------------------------------

let showUnlocked = true;
for (const tab of document.querySelectorAll("#page-players [data-unlocked]")) {
  tab.addEventListener("click", () => {
    showUnlocked = tab.dataset.unlocked === "true";
    loadPlayers().catch((err) => toast(err.message, true));
  });
}

async function loadPlayers() {
  for (const tab of document.querySelectorAll("#page-players [data-unlocked]")) {
    tab.setAttribute("aria-selected", String((tab.dataset.unlocked === "true") === showUnlocked));
  }
  const { fighters } = await api("GET", "/fighters");
  const shown = fighters.filter((f) => f.unlocked === showUnlocked);
  if (shown.length === 0) {
    $("fighters-list").replaceChildren(el("p", { class: "empty" }, showUnlocked ? "No fighters are active. Players can't pick anyone!" : "Every fighter is active."));
    return;
  }
  $("fighters-list").replaceChildren(...shown.map((f) =>
    el("div", { class: "card fighter" },
      el("div", {},
        el("div", { class: "name" }, f.name),
        el("div", { class: "id muted" }, f.unlocked ? "Active: players can pick" : "Inactive: shows as “?”")),
      el("button", {
        type: "button", class: "switch", role: "switch", "aria-checked": String(f.unlocked),
        "aria-label": `${f.name} active`, onclick: (e) => setFighter(f, !f.unlocked, e.currentTarget),
      }))));
}

async function setFighter(fighter, unlocked, button) {
  button.disabled = true;
  button.setAttribute("aria-checked", String(unlocked));
  try {
    await api("PATCH", `/fighters/${encodeURIComponent(fighter.id)}`, { unlocked });
    toast(`${fighter.name} is ${unlocked ? "active" : "inactive"}. Players see it the next time they open character select.`);
    setTimeout(() => loadPlayers().catch((err) => toast(err.message, true)), 400);
  } catch (err) {
    button.setAttribute("aria-checked", String(!unlocked));
    button.disabled = false;
    toast(err.message, true);
  }
}

// ---- Start -----------------------------------------------------------------

(async () => {
  if (!memoryToken) {
    logOut();
    return;
  }
  try {
    const me = await api("GET", "/me");
    showPortal(me.email);
  } catch {
    logOut();
  }
})();
