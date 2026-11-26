// The browser side. Every time we need data, we ask the Python backend with fetch().
// Note: Oracle column names come back in lowercase (l.listingid, l.modelname, ...).

const $ = s => document.querySelector(s);
const money = n => "$" + Number(n).toLocaleString("en-CA", { minimumFractionDigits: 2 });
// esc() stops text typed by users from being treated as HTML
const esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const swatch = { Black: "#1b1b1b", Tan: "#b08457", Red: "#9b2c2c", Navy: "#1f2f4f", White: "#ece7df", Green: "#3f5c47",
  Beige: "#d8c8ab", Gold: "#c9a24b", Brown: "#6b4a32", Monogram: "#8a6a46" };

let user = null;        // the signed-in user (or null)
let view = "shop";      // which page we're on: shop, wishlist or cart
let listings = [];      // the handbags currently shown in the shop
let signup = false;     // is the sign-in pop-up in "create account" mode?

// Send a request to Python and return its answer (or throw an error message)
async function api(url, method = "GET", body) {
  const r = await fetch(url, { method, headers: { "Content-Type": "application/json" }, body: body && JSON.stringify(body) });
  const data = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(data.error || "Something went wrong");
  return data;
}
function toast(msg) {
  const t = $("#toast");
  t.textContent = msg; t.classList.add("show");
  setTimeout(() => t.classList.remove("show"), 2500);
}
const tile = l => `<div class="tile" style="background:${swatch[l.colour] || "#ddd"}"></div>`;

// Draw the current page
async function render() {
  const el = $("#view");
  document.querySelectorAll("nav [data-view]").forEach(b => b.classList.toggle("on", b.dataset.view === view));
  $("#account").textContent = user ? "Sign out" : "Sign in";
  try {
    if (view === "shop") {
      listings = await api("/api/listings");
      el.innerHTML = `<h1>Handbags</h1><div class="grid">${listings.map(l => `
        <article class="card">
          <button class="tile" style="background:${swatch[l.colour] || "#ddd"}" onclick="openDetail(${l.listingid})"
                  aria-label="View ${esc(l.designer)} ${esc(l.modelname)}"></button>
          <h3>${esc(l.designer)}</h3>
          <p>${esc(l.modelname)}, ${esc(l.colour)}</p>
          <p>${money(l.price)}</p>
          ${l.authenticationstatus === "Authenticated" ? '<span class="badge">Authenticated</span>' : ""}
        </article>`).join("") || '<p class="empty">No handbags are listed yet. Be the first to sell one.</p>'}</div>`;
    } else if (!user) {
      el.innerHTML = `<h1>${view === "cart" ? "Cart" : "Wishlist"}</h1><p class="empty">Sign in to see your ${view}.</p>`;
    } else {
      const items = await api("/api/" + view);
      const rows = items.map(i => `<div class="row"><span>${esc(i.designer)} ${esc(i.modelname)}</span><span>${money(i.price)}
        ${view === "wishlist" ? `<button class="link" onclick="act('cart',${i.listingid},'POST')">Add to cart</button>` : ""}
        <button class="link" onclick="act('${view}',${i.listingid},'DELETE')">Remove</button></span></div>`).join("");
      const sub = items.reduce((s, i) => s + i.price, 0);
      el.innerHTML = `<h1>${view === "cart" ? "Cart" : "Wishlist"}</h1>${rows || `<p class="empty">Your ${view} is empty.</p>`}
        ${view === "cart" && items.length ? `<p>Subtotal ${money(sub)}. Tax and shipping are added at checkout.</p>
        <button class="solid" onclick="checkout()">Place order</button>` : ""}`;
    }
  } catch (e) { toast(e.message); }
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

// Handbag details pop-up (with reviews)
async function openDetail(id) {
  const l = listings.find(x => x.listingid === id), rv = await api("/api/reviews/" + id);
  $("#detailDialog").innerHTML = `
    ${tile(l)}<h2>${esc(l.designer)} ${esc(l.modelname)}</h2>
    <p>${esc(l.description)}</p>
    <p>${money(l.price)}. Condition: ${esc(l.handbagcondition)}. Authentication: ${esc(l.authenticationstatus || "None")}. Pickup: ${esc(l.pickuplocation)}.</p>
    <button class="solid" onclick="act('cart',${id},'POST')">Add to cart</button>
    <button class="link" onclick="act('wishlist',${id},'POST')">Save</button>
    <button class="link" onclick="detailDialog.close()">Close</button>
    <h3>Reviews</h3>
    ${rv.map(r => `<div class="review">${r.rating}/5 from ${esc(r.firstname)}: ${esc(r.comments)}</div>`).join("") || '<p class="empty">No reviews yet.</p>'}
    ${user ? `<form onsubmit="review(event,${id})"><select name="rating">${[5, 4, 3, 2, 1].map(n => `<option>${n}</option>`).join("")}</select>
      <textarea name="comments" placeholder="Write a review" required></textarea><button class="solid">Post review</button></form>` : ""}`;
  $("#detailDialog").showModal();
}
async function review(e, id) {
  e.preventDefault();
  try {
    await api("/api/reviews", "POST", { listingID: id, ...Object.fromEntries(new FormData(e.target)) });
    toast("Review posted"); detailDialog.close();
  } catch (err) { toast(err.message); }
}

// SELL: open the form, then send it to Python, which saves it in Oracle
$("#sell").onclick = () => user ? sellDialog.showModal() : (setAuthMode(false), authDialog.showModal());
$("#sellForm").onsubmit = async e => {
  e.preventDefault();
  try {
    await api("/api/listings", "POST", Object.fromEntries(new FormData(e.target)));
    e.target.reset(); sellDialog.close(); toast("Listing posted");
    view = "shop"; render();
  } catch (err) { toast(err.message); }
};

// Sign in / create account
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
document.querySelectorAll("nav [data-view]").forEach(b => b.onclick = () => { view = b.dataset.view; render(); });

// On page load: find out who is signed in, then draw the shop
(async () => { user = await api("/api/me"); render(); })();
