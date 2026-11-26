/* MIGRATION: run this ONLY if your tables already exist in Oracle from the earlier script.
   (A fresh install uses schema_oracle.sql instead and does not need this file.)
   It splits OrderTotal out of Orders (fixes the BCNF violation) and adds the missing UNIQUE rules. */

CREATE TABLE OrderTotal (
    Subtotal NUMBER(10,2) NOT NULL,
    TaxAmount NUMBER(10,2) NOT NULL,
    ShippingCharge NUMBER(10,2) NOT NULL,
    TotalAmount NUMBER(10,2) NOT NULL,
    PRIMARY KEY (Subtotal, TaxAmount, ShippingCharge),
    CHECK (TotalAmount = Subtotal + TaxAmount + ShippingCharge)
);

INSERT INTO OrderTotal (Subtotal, TaxAmount, ShippingCharge, TotalAmount)
  SELECT DISTINCT Subtotal, TaxAmount, ShippingCharge, TotalAmount FROM Orders;

ALTER TABLE Orders ADD FOREIGN KEY (Subtotal, TaxAmount, ShippingCharge)
  REFERENCES OrderTotal (Subtotal, TaxAmount, ShippingCharge);
ALTER TABLE Orders DROP COLUMN TotalAmount;

/* One cart / one wishlist per user, and no duplicate rows inside them */
ALTER TABLE ShoppingCart ADD CONSTRAINT uq_cart_user UNIQUE (UserID);
ALTER TABLE Wishlist ADD CONSTRAINT uq_wishlist_user UNIQUE (UserID);
ALTER TABLE CartItem ADD CONSTRAINT uq_cartitem UNIQUE (CartID, ListingID);
ALTER TABLE WishlistItem ADD CONSTRAINT uq_wishlistitem UNIQUE (WishlistID, ListingID);
ALTER TABLE Review ADD CONSTRAINT uq_review UNIQUE (UserID, ListingID);
ALTER TABLE Shipping ADD CONSTRAINT uq_shipping UNIQUE (OrderID, SellerID);

COMMIT;
