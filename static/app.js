// The browser side. Every time we need data, we ask the Python backend with fetch().
// Note: Oracle column names come back in lowercase (l.listingid, l.modelname, ...).

const $ = s => document.querySelector(s);
const money = n => "$" + Number(n).toLocaleString("en-CA", { minimumFractionDigits: 2 });
// esc() stops text typed by users from being treated as HTML
const esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

// Handbag colour name -> colour on screen
const swatch = { Black: "#1f1b18", Tan: "#b4875a", Red: "#8f2d2d", Navy: "#25365a", White: "#faf7f2", Green: "#3d5a45",
  Beige: "#d9c8aa", Gold: "#c9a24b", Brown: "#6b4a32", Monogram: "#8a6a46" };
const colourOf = name => swatch[name] || "#c9bfb3";

// A simple handbag drawing, filled with the bag's colour
const bag = c => `<svg viewBox="0 0 100 100" aria-hidden="true">
  <path d="M32 40C32 10 68 10 68 40" fill="none" stroke="${c}" stroke-width="3.5" stroke-linecap="round"/>
  <path d="M18 40h64l6 46c.4 3-1.5 5-4.5 5h-67c-3 0-4.9-2-4.5-5z" fill="${c}" stroke="rgba(0,0,0,.18)"/>
  <rect x="44" y="52" width="12" height="8" rx="1.5" fill="rgba(255,255,255,.4)"/></svg>`;

let user = null;        // the signed-in user (or null)
let view = "shop";      // which page we're on: shop, wishlist or cart
let listings = [];      // the handbags currently in the shop
let filter = "";        // designer filter ("" = all)
let signup = false;     // is the sign-in pop-up in "create account" mode?

// Send a request to Python and return its answer (or throw an error message)
async function api(url, method = "GET", body) {
  let r;
  try {
    r = await fetch(url, { method, headers: { "Content-Type": "application/json" }, body: body && JSON.stringify(body) });
  } catch {
    throw new Error("Can't reach the server. Start it with python3 app.py, then open http://127.0.0.1:5000");
  }
  const data = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(data.error || `Server error (${r.status}). Open the site through python3 app.py, not as a plain file.`);
  return data;
}
function toast(msg) {
  const t = $("#toast");
  t.textContent = msg; t.classList.add("show");
  setTimeout(() => t.classList.remove("show"), 3000);
}

// ---- Shop page ----
const card = l => `<article class="card">
  <button class="tile" onclick="openDetail(${l.listingid})" aria-label="View ${esc(l.designer)} ${esc(l.modelname)}">${bag(colourOf(l.colour))}</button>
  <h3>${esc(l.designer)}</h3>
  <p class="muted">${esc(l.modelname)}</p>
  <p class="price">${money(l.price)}</p>
  ${l.authenticationstatus === "Authenticated" ? '<span class="badge">Authenticated</span>' : ""}
</article>`;

function drawShop() {
  const designers = [...new Set(listings.map(l => l.designer))].sort();
  const shown = filter ? listings.filter(l => l.designer === filter) : listings;
  $("#view").innerHTML = `
    <div class="head"><h1>The collection</h1><span class="muted">${shown.length} handbag${shown.length === 1 ? "" : "s"}</span></div>
    <div class="chips">${["", ...designers].map(d =>
      `<button class="chip${d === filter ? " on" : ""}" data-designer="${esc(d)}">${d ? esc(d) : "All"}</button>`).join("")}</div>
    <div class="grid">${shown.map(card).join("") || '<p class="empty">No handbags match yet. Pick another designer, or sell one of your own.</p>'}</div>`;
}

// ---- Draw the current page ----
async function render() {
  const el = $("#view"), title = view === "cart" ? "Your cart" : "Your wishlist";
  document.querySelectorAll(".site-header [data-view]").forEach(b => b.classList.toggle("on", b.dataset.view === view));
  $("#hero").hidden = view !== "shop";
  $("#account").textContent = user ? "Sign out" : "Sign in";
  try {
    if (view === "shop") {
      listings = await api("/api/listings");
      drawShop();
    } else if (!user) {
      el.innerHTML = `<h1>${title}</h1><p class="empty">Sign in to see your ${view}.</p>`;
    } else {
      const items = await api("/api/" + view);
      const rows = items.map(i => `<div class="row">
        <div class="thumb">${bag(colourOf(i.colour))}</div>
        <div><strong>${esc(i.designer)}</strong><br><span class="muted">${esc(i.modelname)}</span></div>
        <div class="actions"><span class="price">${money(i.price)}</span>
          ${view === "wishlist" ? `<button class="link" onclick="act('cart',${i.listingid},'POST')">Add to cart</button>` : ""}
          <button class="link" onclick="act('${view}',${i.listingid},'DELETE')">Remove</button></div></div>`).join("");
      const sub = items.reduce((s, i) => s + i.price, 0);
      el.innerHTML = `<h1>${title}</h1>
        ${rows || `<p class="empty">Nothing here yet. <button class="link" data-view="shop">Browse the collection</button></p>`}
        ${view === "cart" && items.length ? `<div class="summary"><p class="muted">Subtotal ${money(sub)}. Tax and shipping are added at checkout.</p>
          <button class="solid" onclick="checkout()">Place order</button></div>` : ""}`;
    }
  } catch (e) {
    el.innerHTML = `<p class="empty">${esc(e.message)}</p>`;
  }
}

// Add to / remove from the cart or wishlist
async function act(kind, id, method) {
  try {
    await api(`/api/${kind}${method === "DELETE" ? "/" + id : ""}`, method, { listingID: id });
    toast(method === "DELETE" ? "Removed" : kind === "cart" ? "Added to cart" : "Saved to wishlist");
    if (method === "DELETE" || view !== "shop") render();
  } catch (e) { toast(e.message); }
}

async function checkout() {
  try {
    const o = await api("/api/checkout", "POST");
    toast(`Order #${o.order_id} placed. Total ${money(o.total)}`);
    view = "shop"; render();
  } catch (e) { toast(e.message); }
}

// ---- Handbag details pop-up (with reviews) ----
async function openDetail(id) {
  const l = listings.find(x => x.listingid === id);
  let rv = [];
  try { rv = await api("/api/reviews/" + id); } catch (e) { toast(e.message); }
  $("#detailDialog").innerHTML = `<div class="detail">
    <div class="art">${bag(colourOf(l.colour))}</div>
    <div class="info">
      <h2>${esc(l.designer)}</h2>
      <p class="muted">${esc(l.modelname)}</p>
      <p class="price">${money(l.price)}</p>
      <p>${esc(l.description)}</p>
      <dl><dt>Colour</dt><dd>${esc(l.colour)}</dd><dt>Condition</dt><dd>${esc(l.handbagcondition)}</dd>
        <dt>Authentication</dt><dd>${esc(l.authenticationstatus || "None")}</dd><dt>Pickup</dt><dd>${esc(l.pickuplocation)}</dd></dl>
      <button class="solid" onclick="act('cart',${id},'POST')">Add to cart</button>
      <button class="ghost" onclick="act('wishlist',${id},'POST')">Save for later</button>
      <h3>Reviews</h3>
      ${rv.map(r => `<div class="review">${r.rating}/5 from ${esc(r.firstname)}: ${esc(r.comments)}</div>`).join("") || '<p class="empty">No reviews yet.</p>'}
      ${user ? `<form onsubmit="review(event,${id})"><select name="rating" aria-label="Rating">${[5, 4, 3, 2, 1].map(n => `<option>${n}</option>`).join("")}</select>
        <textarea name="comments" placeholder="Write a review" rows="2" required></textarea><button class="solid">Post review</button></form>` : ""}
    </div>
    <button class="x" aria-label="Close" onclick="detailDialog.close()">&times;</button></div>`;
  $("#detailDialog").showModal();
}
async function review(e, id) {
  e.preventDefault();
  try {
    await api("/api/reviews", "POST", { listingID: id, ...Object.fromEntries(new FormData(e.target)) });
    toast("Review posted"); detailDialog.close();
  } catch (err) { toast(err.message); }
}

// ---- Sell: send the form to Python, which saves it in Oracle ----
$("#sellForm").onsubmit = async e => {
  e.preventDefault();
  try {
    await api("/api/listings", "POST", Object.fromEntries(new FormData(e.target)));
    e.target.reset(); sellDialog.close(); toast("Listing posted");
    view = "shop"; render();
  } catch (err) { toast(err.message); }
};

// ---- Sign in / create account ----
function setAuthMode(on) {
  signup = on;
  $("#nameFields").hidden = !on;
  $("#authTitle").textContent = $("#authSubmit").textContent = on ? "Create account" : "Sign in";
  $("#authSwitch").textContent = on ? "I already have an account" : "Create an account";
}
$("#authSwitch").onclick = () => setAuthMode(!signup);
$("#authForm").onsubmit = async e => {
  e.preventDefault();
  try {
    await api(signup ? "/api/register" : "/api/login", "POST", Object.fromEntries(new FormData(e.target)));
    user = await api("/api/me"); authDialog.close(); toast("Welcome"); render();
  } catch (err) { toast(err.message); }
};
$("#account").onclick = async () => {
  if (user) { await api("/api/logout", "POST"); user = null; view = "shop"; render(); }
  else { setAuthMode(false); authDialog.showModal(); }
};

// ---- Clicks on menu links, designer filters and Sell buttons (works for anything added later too) ----
document.addEventListener("click", e => {
  const v = e.target.closest("[data-view]"), d = e.target.closest("[data-designer]"), s = e.target.closest("[data-action='sell']");
  if (v) { view = v.dataset.view; render(); window.scrollTo(0, 0); }
  if (d) { filter = d.dataset.designer; drawShop(); }
  if (s) { if (user) sellDialog.showModal(); else { setAuthMode(false); authDialog.showModal(); } }
});

// On page load: find out who is signed in, then draw the shop
(async () => { try { user = await api("/api/me"); } catch {} render(); })();
