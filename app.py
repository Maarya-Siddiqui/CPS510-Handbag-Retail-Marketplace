"""
Backend for the handbag marketplace.

  Browser (HTML/CSS/JS)  <-->  this Python file (Flask)  <-->  Oracle database

The browser can't talk to Oracle directly. It asks this file, this file runs
SQL (the same kind you run in SQL Developer) and sends the results back.
"""
import uuid
import oracledb
from flask import Flask, g, jsonify, request, session, send_from_directory, abort
from werkzeug.security import generate_password_hash, check_password_hash

# ---- 1. EDIT THESE: use the same details as your SQL Developer connection ----
DB_USER = "your_username"
DB_PASSWORD = "your_password"
DB_DSN = "hostname:1521/service_name"      # host:port/service_name

app = Flask(__name__, static_folder="static", static_url_path="/static")
app.secret_key = "change-this-to-any-long-random-text"


# ---- 2. Talking to Oracle: small helpers used by every route below ----
def db():
    """Open one Oracle connection per request (and reuse it within that request)."""
    if "conn" not in g:
        g.conn = oracledb.connect(user=DB_USER, password=DB_PASSWORD, dsn=DB_DSN)
    return g.conn

@app.teardown_appcontext
def close_db(_):
    conn = g.pop("conn", None)
    if conn:
        conn.close()

def select(sql, **params):
    """Run a SELECT. Returns a list of dicts, e.g. [{'listingid': 1, 'price': 5200}, ...]."""
    cur = db().cursor()
    cur.execute(sql, params)
    names = [c[0].lower() for c in cur.description]   # Oracle returns UPPERCASE names
    return [dict(zip(names, row)) for row in cur.fetchall()]

def one(sql, **params):
    """Run a SELECT and return just the first value (or None)."""
    rows = db().cursor().execute(sql, params).fetchmany(1)
    return rows[0][0] if rows else None

def run(sql, **params):
    """Run an INSERT / UPDATE / DELETE. Call db().commit() when you're done."""
    db().cursor().execute(sql, params)

def insert(sql, **params):
    """INSERT and get back the new ID. The SQL must end with: RETURNING <IdColumn> INTO :new_id"""
    cur = db().cursor()
    new_id = cur.var(int)
    cur.execute(sql, {**params, "new_id": new_id})
    return new_id.getvalue()[0]

def need_user():
    if "user_id" not in session:
        abort(401, "Please sign in first")
    return session["user_id"]

def password_ok(stored, given):
    if stored.startswith(("scrypt:", "pbkdf2:")):      # accounts created on the website (hashed)
        return check_password_hash(stored, given)
    return stored == given                              # sample users from the SQL script (plain text)

def active_cart(uid):
    """The user's one cart (each user has exactly one). Makes it, or re-opens it empty if it was checked out."""
    row = select("SELECT CartID, CartStatus FROM ShoppingCart WHERE UserID = :u", u=uid)
    if not row:
        return insert("""INSERT INTO ShoppingCart (CartID, UserID, CreatedDate, CartStatus)
                         VALUES (cart_seq.NEXTVAL, :u, SYSDATE, 'Active') RETURNING CartID INTO :new_id""", u=uid)
    cid = row[0]["cartid"]
    if row[0]["cartstatus"] != "Active":
        run("DELETE FROM CartItem WHERE CartID = :c", c=cid)
        run("UPDATE ShoppingCart SET CartStatus = 'Active' WHERE CartID = :c", c=cid)
        db().commit()
    return cid

def user_wishlist(uid):
    wid = one("SELECT MIN(WishlistID) FROM Wishlist WHERE UserID = :u", u=uid)
    if wid is None:
        wid = insert("""INSERT INTO Wishlist (WishlistID, UserID, CreatedDate)
                        VALUES (wishlist_seq.NEXTVAL, :u, SYSDATE) RETURNING WishlistID INTO :new_id""", u=uid)
    return wid

@app.errorhandler(400)
@app.errorhandler(401)
def show_error(e):
    return jsonify(error=e.description), e.code


# ---- 3. Pages ----
@app.get("/")
def home():
    return send_from_directory("static", "index.html")


# ---- 4. Accounts ----
@app.get("/api/me")
def me():
    uid = session.get("user_id")
    rows = select("SELECT UserID, FirstName FROM Users WHERE UserID = :u", u=uid) if uid else []
    return jsonify(rows[0] if rows else None)

@app.post("/api/register")
def register():
    d = request.json
    if not all(d.get(k) for k in ("firstName", "lastName", "email", "password", "address")):
        abort(400, "Please fill in every field")
    try:
        uid = insert("""INSERT INTO Users (UserID, FirstName, LastName, Email, Password, Address)
                        VALUES (users_seq.NEXTVAL, :fname, :lname, :email, :pw, :addr)
                        RETURNING UserID INTO :new_id""",
                     fname=d["firstName"], lname=d["lastName"], email=d["email"],
                     pw=generate_password_hash(d["password"]), addr=d["address"])
    except oracledb.IntegrityError:
        abort(400, "That email is already registered")
    db().commit()
    session["user_id"] = uid
    return jsonify(ok=True)

@app.post("/api/login")
def login():
    d = request.json
    rows = select("SELECT UserID, Password FROM Users WHERE Email = :email", email=d.get("email"))
    if not rows or not password_ok(rows[0]["password"], d.get("password", "")):
        abort(401, "Email or password is incorrect")
    session["user_id"] = rows[0]["userid"]
    return jsonify(ok=True)

@app.post("/api/logout")
def logout():
    session.clear()
    return jsonify(ok=True)


# ---- 5. Listings (browse + SELL) ----
@app.get("/api/listings")
def get_listings():
    return jsonify(select("""
        SELECT l.ListingID, l.Price, l.PickupLocation, h.Designer, h.ModelName, h.Colour,
               h.HandbagCondition, h.Description, a.AuthenticationStatus
        FROM Listing l
        JOIN Handbag h ON h.HandbagID = l.HandbagID
        LEFT JOIN Authentication a ON a.HandbagID = h.HandbagID
        WHERE l.AvailabilityStatus = 'Available'
        ORDER BY l.ListingID DESC"""))

@app.post("/api/listings")
def create_listing():
    uid, d = need_user(), request.json
    try:
        price = float(d["price"])
        if price <= 0:
            raise ValueError
        # step 1: the handbag itself
        hid = insert("""INSERT INTO Handbag (HandbagID, Designer, ModelName, Colour, HandbagCondition, Description, SerialNumber)
                        VALUES (handbag_seq.NEXTVAL, :designer, :model, :colour, :cond, :descr, :serial)
                        RETURNING HandbagID INTO :new_id""",
                     designer=d["designer"], model=d["modelName"], colour=d["colour"],
                     cond=d["condition"], descr=d.get("description", ""), serial=d["serialNumber"])
    except oracledb.IntegrityError:
        abort(400, "A handbag with that serial number is already listed")
    except (KeyError, ValueError):
        abort(400, "Please fill in every field with valid values")
    # step 2: the listing (who is selling it, for how much)
    run("""INSERT INTO Listing (ListingID, HandbagID, UserID, Price, ListingDate, AvailabilityStatus, PickupLocation)
           VALUES (listing_seq.NEXTVAL, :h, :u, :price, SYSDATE, 'Available', :loc)""",
        h=hid, u=uid, price=price, loc=d["pickupLocation"])
    # step 3: an authentication record, waiting for review
    run("""INSERT INTO Authentication (AuthenticationID, HandbagID, AuthenticationStatus, AuthenticationDate,
                                       AuthenticationMethod, CertificateNumber)
           VALUES (auth_seq.NEXTVAL, :h, 'Pending', SYSDATE, 'Professional Authenticator Review', :cert)""",
        h=hid, cert="CERT-" + uuid.uuid4().hex[:10].upper())
    db().commit()
    return jsonify(ok=True)


# ---- 6. Reviews ----
@app.get("/api/reviews/<int:listing_id>")
def get_reviews(listing_id):
    return jsonify(select("""SELECT r.Rating, r.Comments, u.FirstName FROM Review r
                             JOIN Users u ON u.UserID = r.UserID
                             WHERE r.ListingID = :l ORDER BY r.ReviewID DESC""", l=listing_id))

@app.post("/api/reviews")
def add_review():
    uid, d = need_user(), request.json
    try:
        if one("SELECT COUNT(*) FROM Review WHERE UserID = :u AND ListingID = :l", u=uid, l=d["listingID"]):
            abort(400, "You have already reviewed this listing")
        run("""INSERT INTO Review (ReviewID, UserID, ListingID, Rating, Comments, DateSubmitted)
               VALUES (review_seq.NEXTVAL, :u, :l, :rating, :text, SYSDATE)""",
            u=uid, l=d["listingID"], rating=int(d["rating"]), text=d["comments"])
        db().commit()
    except (oracledb.IntegrityError, KeyError, ValueError):
        abort(400, "That rating is not valid")
    return jsonify(ok=True)


# ---- 7. Cart ----
@app.get("/api/cart")
def get_cart():
    uid = need_user()
    return jsonify(select("""
        SELECT l.ListingID, ci.PriceAdded AS Price, h.Designer, h.ModelName
        FROM ShoppingCart c
        JOIN CartItem ci ON ci.CartID = c.CartID
        JOIN Listing l ON l.ListingID = ci.ListingID
        JOIN Handbag h ON h.HandbagID = l.HandbagID
        WHERE c.UserID = :u AND c.CartStatus = 'Active' AND l.AvailabilityStatus = 'Available'""", u=uid))

@app.post("/api/cart")
def add_to_cart():
    uid, lid = need_user(), request.json["listingID"]
    row = select("SELECT Price, UserID FROM Listing WHERE ListingID = :l AND AvailabilityStatus = 'Available'", l=lid)
    if not row:
        abort(400, "That handbag is no longer available")
    if row[0]["userid"] == uid:
        abort(400, "You can't buy your own listing")
    cid = active_cart(uid)
    if not one("SELECT COUNT(*) FROM CartItem WHERE CartID = :c AND ListingID = :l", c=cid, l=lid):
        run("""INSERT INTO CartItem (CartItemID, CartID, ListingID, Quantity, PriceAdded)
               VALUES (cartitem_seq.NEXTVAL, :c, :l, 1, :p)""", c=cid, l=lid, p=row[0]["price"])
        db().commit()
    return jsonify(ok=True)

@app.delete("/api/cart/<int:listing_id>")
def remove_from_cart(listing_id):
    uid = need_user()
    run("""DELETE FROM CartItem WHERE ListingID = :l AND CartID IN
           (SELECT CartID FROM ShoppingCart WHERE UserID = :u AND CartStatus = 'Active')""", l=listing_id, u=uid)
    db().commit()
    return jsonify(ok=True)


# ---- 8. Wishlist ----
@app.get("/api/wishlist")
def get_wishlist():
    uid = need_user()
    return jsonify(select("""
        SELECT l.ListingID, l.Price, h.Designer, h.ModelName
        FROM Wishlist w
        JOIN WishlistItem wi ON wi.WishlistID = w.WishlistID
        JOIN Listing l ON l.ListingID = wi.ListingID
        JOIN Handbag h ON h.HandbagID = l.HandbagID
        WHERE w.UserID = :u AND l.AvailabilityStatus = 'Available'""", u=uid))

@app.post("/api/wishlist")
def add_to_wishlist():
    uid, lid = need_user(), request.json["listingID"]
    wid = user_wishlist(uid)
    if not one("SELECT COUNT(*) FROM WishlistItem WHERE WishlistID = :w AND ListingID = :l", w=wid, l=lid):
        run("""INSERT INTO WishlistItem (WishlistItemID, WishlistID, ListingID, AddedDate)
               VALUES (wishlistitem_seq.NEXTVAL, :w, :l, SYSDATE)""", w=wid, l=lid)
        db().commit()
    return jsonify(ok=True)

@app.delete("/api/wishlist/<int:listing_id>")
def remove_from_wishlist(listing_id):
    uid = need_user()
    run("""DELETE FROM WishlistItem WHERE ListingID = :l AND WishlistID IN
           (SELECT WishlistID FROM Wishlist WHERE UserID = :u)""", l=listing_id, u=uid)
    db().commit()
    return jsonify(ok=True)


# ---- 9. Checkout: turns the cart into an order ----
@app.post("/api/checkout")
def checkout():
    uid = need_user()
    cid = active_cart(uid)
    items = select("""SELECT ci.ListingID, ci.PriceAdded, l.UserID AS SellerID
                      FROM CartItem ci JOIN Listing l ON l.ListingID = ci.ListingID
                      WHERE ci.CartID = :c AND l.AvailabilityStatus = 'Available'""", c=cid)
    if not items:
        abort(400, "Your cart is empty")

    addr = one("SELECT Address FROM Users WHERE UserID = :u", u=uid)
    subtotal = round(sum(i["priceadded"] for i in items), 2)
    tax, shipping = round(subtotal * 0.13, 2), 25.0          # 13% HST + flat shipping
    total = round(subtotal + tax + shipping, 2)

    # OrderTotal holds each (Subtotal, TaxAmount, ShippingCharge) -> TotalAmount combination once
    if not one("""SELECT COUNT(*) FROM OrderTotal WHERE Subtotal = ROUND(:sub, 2)
                  AND TaxAmount = ROUND(:tax, 2) AND ShippingCharge = ROUND(:ship, 2)""",
               sub=subtotal, tax=tax, ship=shipping):
        run("INSERT INTO OrderTotal (Subtotal, TaxAmount, ShippingCharge, TotalAmount) VALUES (:sub, :tax, :ship, :total)",
            sub=subtotal, tax=tax, ship=shipping, total=total)
    oid = insert("""INSERT INTO Orders (OrderID, BuyerID, OrderDate, OrderStatus, Subtotal, TaxAmount, ShippingCharge,
                                        BillingAddress, ShippingAddress)
                    VALUES (orders_seq.NEXTVAL, :u, SYSDATE, 'Confirmed', :sub, :tax, :ship, :addr, :addr)
                    RETURNING OrderID INTO :new_id""",
                 u=uid, sub=subtotal, tax=tax, ship=shipping, addr=addr)
    for i in items:
        run("INSERT INTO OrderItem (OrderItemID, OrderID, ListingID) VALUES (orderitem_seq.NEXTVAL, :o, :l)",
            o=oid, l=i["listingid"])
        run("UPDATE Listing SET AvailabilityStatus = 'Sold' WHERE ListingID = :l", l=i["listingid"])
    run("""INSERT INTO Payment (PaymentID, OrderID, PaymentAmount, PaymentMethod, TransactionDate, PaymentStatus, TransactionReference)
           VALUES (payment_seq.NEXTVAL, :o, :total, 'Credit Card', SYSDATE, 'Completed', :ref)""",
        o=oid, total=total, ref=uuid.uuid4().hex)
    for seller in {i["sellerid"] for i in items}:            # one shipment per seller
        run("""INSERT INTO Shipping (ShippingID, OrderID, SellerID, Carrier, TrackingNumber, CurrentLocation,
                                     EstimatedDeliveryDate, DeliveryStatus)
               VALUES (shipping_seq.NEXTVAL, :o, :s, 'Canada Post', :track, 'Seller', SYSDATE + 5, 'Pending')""",
            o=oid, s=seller, track=uuid.uuid4().hex[:12].upper())
    run("UPDATE ShoppingCart SET CartStatus = 'Checked Out' WHERE CartID = :c", c=cid)
    db().commit()                                            # save everything at once
    return jsonify(order_id=oid, total=total)


if __name__ == "__main__":
    app.run(debug=True)
