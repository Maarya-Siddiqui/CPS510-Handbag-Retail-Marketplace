# Maison Archive — Designer Handbag Marketplace

A responsive boutique-style frontend prototype plus a FastAPI backend starter for the Oracle database documented in your project.

## What's included

- `index.html` — responsive storefront with home, collection tiles, product grid, search, condition filter, sort, product detail modal, local demo cart and wishlist.
- `backend/main.py` — FastAPI endpoints that read available listings from Oracle by joining `Listing` and `Handbag`.
- `backend/requirements.txt` — Python dependencies.
- `backend/.env.example` — Oracle connection settings template.

## 1. Start the frontend demo

You can open `index.html` directly in a browser to explore the demo inventory. For a local web server, from this folder run:

```bash
python3 -m http.server 5500
```

Then visit `http://127.0.0.1:5500`.

The cart and wishlist currently use browser memory only. They are interface demonstrations, not saved to Oracle.

## 2. Configure the Python API

Use the Python environment you normally use for your course project. From the project folder:

```bash
cd backend
python3 -m pip install -r requirements.txt
cp .env.example .env
```

Edit `.env` and enter the Oracle username/password for the schema that owns your marketplace tables. The example DSN is for a local Oracle Free container exposing port 1521 and service `FREEPDB1`. If your service name or port differs, update `ORACLE_DSN`.

Do not put database credentials in `index.html` or JavaScript.

## 3. Run the API

From the `backend` directory:

```bash
uvicorn main:app --reload --port 8000
```

Test the connection:

- `http://127.0.0.1:8000/api/health`
- `http://127.0.0.1:8000/api/listings`
- `http://127.0.0.1:8000/docs`

## 4. Connect the storefront to live listings

Start the frontend server in a second terminal:

```bash
cd ..
python3 -m http.server 5500
```

Open:

`http://127.0.0.1:5500/?api=1`

The `?api=1` switch tells the page to request `GET http://127.0.0.1:8000/api/listings`. If the API is unavailable, the page keeps showing its sample inventory.

## 5. How the database query works

The API uses this relationship from your schema:

```sql
SELECT
    l.ListingID,
    l.HandbagID,
    l.UserID AS SellerID,
    l.Price,
    l.ListingDate,
    l.AvailabilityStatus,
    l.PickupLocation,
    h.Designer,
    h.ModelName,
    h.Colour,
    h.HandbagCondition,
    h.Description
FROM Listing l
JOIN Handbag h ON h.HandbagID = l.HandbagID
WHERE UPPER(l.AvailabilityStatus) = 'AVAILABLE'
ORDER BY l.ListingDate DESC NULLS LAST;
```

`Listing.HandbagID` links each listing to its handbag. The frontend displays the listing price and the handbag's designer/model/colour/condition/description.

## 6. Important schema notes before enabling more features

Your supplied schema does not show a handbag photo/image field. The storefront therefore uses temporary editorial placeholder images. For real listing photos, add an `ImageURL` field to `Handbag` or, preferably, a separate `HandbagImage` table if one handbag can have multiple photos. Store image files in a file/object store and save their URLs in the database; avoid storing large image files directly in ordinary relational columns for this student project unless your course requires it.

The API starter intentionally does not implement login, checkout, payment processing, cart persistence or order creation. Those operations need to be built against your actual constraints, foreign keys, ID-generation strategy (identity columns/sequences), and authentication rules. Do not collect or store raw card details. Never return the `Users.Password` value to the browser; store only salted password hashes and verify them on the backend.

The current API assumes:
- `Listing.AvailabilityStatus` uses the value `Available` for active listings.
- `Listing.Price` is numeric.
- Table and column names match the relation names in your documentation.
- The backend database user has `SELECT` permission on `Listing` and `Handbag`.

If your actual Oracle tables were created with quoted mixed-case identifiers, the SQL identifiers may need double quotes. If they were created normally without quotes, Oracle treats unquoted identifiers as uppercase and the query above is appropriate.

## 7. Suggested next implementation order

1. Add and store handbag image URLs.
2. Add seller display names by joining `Listing.UserID` to `Users.UserID`.
3. Add user registration/login with secure password hashing and server-side sessions or tokens.
4. Persist `ShoppingCart` and `CartItem` with API endpoints.
5. Persist `Wishlist` and `WishlistItem`.
6. Implement order creation with `Orders` and `OrderItem`.
7. Add payment status/transaction reference handling and shipping updates.
8. Display authentication and review information on product pages.

This is a course-project starter, not a production-ready commerce/payment system.
