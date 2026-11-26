/* =========== CREATE TABLES ============================================*/
/* DESIGNER HANDBAG RESALE MARKETPLACE (14 tables, BCNF) */

/* 1. USERS */
CREATE TABLE Users (
    UserID NUMBER PRIMARY KEY,
    FirstName VARCHAR2(50) NOT NULL,
    LastName VARCHAR2(50) NOT NULL,
    DateOfBirth DATE,
    Email VARCHAR2(100) NOT NULL UNIQUE,
    Password VARCHAR2(255) NOT NULL,
    PhoneNumber VARCHAR2(20),
    Address VARCHAR2(255)
);

/* 2. HANDBAG */
CREATE TABLE Handbag (
    HandbagID NUMBER PRIMARY KEY,
    Designer VARCHAR2(100) NOT NULL,
    ModelName VARCHAR2(100) NOT NULL,
    Colour VARCHAR2(50),
    HandbagCondition VARCHAR2(50),
    Description VARCHAR2(500),
    SerialNumber VARCHAR2(100) UNIQUE
);

/* 3. LISTING */
CREATE TABLE Listing (
    ListingID NUMBER PRIMARY KEY,
    HandbagID NUMBER NOT NULL REFERENCES Handbag(HandbagID),
    UserID NUMBER NOT NULL REFERENCES Users(UserID),
    Price NUMBER(10,2) NOT NULL CHECK (Price > 0),
    ListingDate DATE NOT NULL,
    AvailabilityStatus VARCHAR2(20) DEFAULT 'Available' NOT NULL,
    PickupLocation VARCHAR2(255)
);

/* 4. AUTHENTICATION */
CREATE TABLE Authentication (
    AuthenticationID NUMBER PRIMARY KEY,
    HandbagID NUMBER NOT NULL REFERENCES Handbag(HandbagID),
    AuthenticationStatus VARCHAR2(30) NOT NULL
        CHECK (AuthenticationStatus IN ('Pending', 'Authenticated', 'Not Authenticated')),
    AuthenticationDate DATE,
    AuthenticationMethod VARCHAR2(100),
    CertificateNumber VARCHAR2(100) UNIQUE
);

/* 5. SHOPPING CART */
CREATE TABLE ShoppingCart (
    CartID NUMBER PRIMARY KEY,
    UserID NUMBER NOT NULL UNIQUE REFERENCES Users(UserID),
    CreatedDate DATE NOT NULL,
    CartStatus VARCHAR2(20) DEFAULT 'Active' NOT NULL
        CHECK (CartStatus IN ('Active', 'Checked Out', 'Abandoned'))
);

/* 6. CART ITEM */
CREATE TABLE CartItem (
    CartItemID NUMBER PRIMARY KEY,
    CartID NUMBER NOT NULL REFERENCES ShoppingCart(CartID),
    ListingID NUMBER NOT NULL REFERENCES Listing(ListingID),
    Quantity NUMBER NOT NULL CHECK (Quantity > 0),
    PriceAdded NUMBER(10,2) NOT NULL CHECK (PriceAdded > 0),
    UNIQUE (CartID, ListingID)
);

/* 7. ORDER TOTAL  (BCNF split: (Subtotal, TaxAmount, ShippingCharge) -> TotalAmount lives here, not in Orders) */
CREATE TABLE OrderTotal (
    Subtotal NUMBER(10,2) NOT NULL,
    TaxAmount NUMBER(10,2) NOT NULL,
    ShippingCharge NUMBER(10,2) NOT NULL,
    TotalAmount NUMBER(10,2) NOT NULL,
    PRIMARY KEY (Subtotal, TaxAmount, ShippingCharge),
    CHECK (TotalAmount = Subtotal + TaxAmount + ShippingCharge)
);

/* 8. ORDERS */
CREATE TABLE Orders (
    OrderID NUMBER PRIMARY KEY,
    BuyerID NUMBER NOT NULL REFERENCES Users(UserID),
    OrderDate DATE NOT NULL,
    OrderStatus VARCHAR2(30) DEFAULT 'Pending' NOT NULL
        CHECK (OrderStatus IN ('Pending', 'Confirmed', 'Shipped', 'Delivered', 'Cancelled')),
    Subtotal NUMBER(10,2) NOT NULL CHECK (Subtotal >= 0),
    TaxAmount NUMBER(10,2) DEFAULT 0 NOT NULL CHECK (TaxAmount >= 0),
    ShippingCharge NUMBER(10,2) DEFAULT 0 NOT NULL CHECK (ShippingCharge >= 0),
    BillingAddress VARCHAR2(255) NOT NULL,
    ShippingAddress VARCHAR2(255) NOT NULL,
    FOREIGN KEY (Subtotal, TaxAmount, ShippingCharge)
        REFERENCES OrderTotal (Subtotal, TaxAmount, ShippingCharge)
);

/* 9. ORDER ITEM  (kept from the normalized design: one row per listing bought in an order) */
CREATE TABLE OrderItem (
    OrderItemID NUMBER PRIMARY KEY,
    OrderID NUMBER NOT NULL REFERENCES Orders(OrderID),
    ListingID NUMBER NOT NULL UNIQUE REFERENCES Listing(ListingID)
);

/* 10. PAYMENT */
CREATE TABLE Payment (
    PaymentID NUMBER PRIMARY KEY,
    OrderID NUMBER NOT NULL REFERENCES Orders(OrderID),
    PaymentAmount NUMBER(10,2) NOT NULL CHECK (PaymentAmount > 0),
    PaymentMethod VARCHAR2(30) NOT NULL,
    TransactionDate DATE NOT NULL,
    PaymentStatus VARCHAR2(20) DEFAULT 'Pending' NOT NULL
        CHECK (PaymentStatus IN ('Pending', 'Completed', 'Declined', 'Refunded')),
    TransactionReference VARCHAR2(100) UNIQUE
);

/* 11. SHIPPING */
CREATE TABLE Shipping (
    ShippingID NUMBER PRIMARY KEY,
    OrderID NUMBER NOT NULL REFERENCES Orders(OrderID),
    SellerID NUMBER NOT NULL REFERENCES Users(UserID),
    Carrier VARCHAR2(50),
    TrackingNumber VARCHAR2(100) UNIQUE,
    CurrentLocation VARCHAR2(255),
    EstimatedDeliveryDate DATE,
    DeliveryStatus VARCHAR2(30) DEFAULT 'Pending' NOT NULL
        CHECK (DeliveryStatus IN ('Pending', 'Shipped', 'On Route', 'Delivered')),
    UNIQUE (OrderID, SellerID)
);

/* 12. REVIEW */
CREATE TABLE Review (
    ReviewID NUMBER PRIMARY KEY,
    UserID NUMBER NOT NULL REFERENCES Users(UserID),
    ListingID NUMBER NOT NULL REFERENCES Listing(ListingID),
    Rating NUMBER NOT NULL CHECK (Rating >= 1 AND Rating <= 5),
    Comments VARCHAR2(500),
    DateSubmitted DATE NOT NULL,
    UNIQUE (UserID, ListingID)
);

/* 13. WISHLIST */
CREATE TABLE Wishlist (
    WishlistID NUMBER PRIMARY KEY,
    UserID NUMBER NOT NULL UNIQUE REFERENCES Users(UserID),
    CreatedDate DATE NOT NULL
);

/* 14. WISHLIST ITEM */
CREATE TABLE WishlistItem (
    WishlistItemID NUMBER PRIMARY KEY,
    WishlistID NUMBER NOT NULL REFERENCES Wishlist(WishlistID),
    ListingID NUMBER NOT NULL REFERENCES Listing(ListingID),
    AddedDate DATE NOT NULL,
    UNIQUE (WishlistID, ListingID)
);


/* ========= DROP TABLE COMMANDS ======================================*/

/*======== INSERTING ROWS INTO TABLES ==================================*/
INSERT INTO Users VALUES (1, 'Aisha', 'Khan', DATE '2001-03-15', 'aisha.khan@email.com', 'Pass1234', '416-555-0101', 'Toronto, ON');
INSERT INTO Users VALUES (2, 'Emily', 'Chen', DATE '1999-07-22', 'emily.chen@email.com', 'Pass2345', '647-555-0102', 'Markham, ON');
INSERT INTO Users VALUES (3, 'Sophia', 'Patel', DATE '2002-11-08', 'sophia.patel@email.com', 'Pass3456', '905-555-0103', 'Brampton, ON');
INSERT INTO Users VALUES (4, 'Olivia', 'Martin', DATE '2000-05-19', 'olivia.martin@email.com', 'Pass4567', '416-555-0104', 'Toronto, ON');
INSERT INTO Users VALUES (5, 'Maya', 'Ahmed', DATE '2003-01-27', 'maya.ahmed@email.com', 'Pass5678', '647-555-0105', 'Mississauga, ON');
INSERT INTO Users VALUES (6, 'Charlotte', 'Wilson', DATE '1998-09-13', 'charlotte.wilson@email.com', 'Pass6789', '416-555-0106', 'Toronto, ON');
INSERT INTO Users VALUES (7, 'Isabella', 'Rossi', DATE '2001-12-02', 'isabella.rossi@email.com', 'Pass7890', '905-555-0107', 'Vaughan, ON');
INSERT INTO Users VALUES (8, 'Amelia', 'Brown', DATE '1997-06-30', 'amelia.brown@email.com', 'Pass8901', '416-555-0108', 'Toronto, ON');
INSERT INTO Users VALUES (9, 'Hannah', 'Lee', DATE '2002-04-17', 'hannah.lee@email.com', 'Pass9012', '647-555-0109', 'Richmond Hill, ON');
INSERT INTO Users VALUES (10, 'Zara', 'Hussain', DATE '2000-10-25', 'zara.hussain@email.com', 'Pass0123', '905-555-0110', 'Brampton, ON');
INSERT INTO Users VALUES (11, 'Grace', 'Thompson', DATE '1999-02-14', 'grace.thompson@email.com', 'Pass1122', '416-555-0111', 'Toronto, ON');
INSERT INTO Users VALUES (12, 'Layla', 'Ali', DATE '2003-08-09', 'layla.ali@email.com', 'Pass2233', '647-555-0112', 'Mississauga, ON');
INSERT INTO Users VALUES (13, 'Nora', 'Williams', DATE '1998-03-21', 'nora.williams@email.com', 'Pass3344', '416-555-0113', 'Toronto, ON');
INSERT INTO Users VALUES (14, 'Sofia', 'Garcia', DATE '2001-11-16', 'sofia.garcia@email.com', 'Pass4455', '905-555-0114', 'Oakville, ON');
INSERT INTO Users VALUES (15, 'Leila', 'Rahman', DATE '2002-07-05', 'leila.rahman@email.com', 'Pass5566', '647-555-0115', 'Toronto, ON');

INSERT INTO Handbag VALUES (1, 'Chanel', 'Classic Flap Bag', 'Black', 'Excellent', 'Timeless quilted handbag with gold-tone hardware', 'CHN001234');
INSERT INTO Handbag VALUES (2, 'Louis Vuitton', 'Neverfull MM', 'Monogram', 'Very Good', 'Classic monogram canvas tote with red interior', 'LV002345');
INSERT INTO Handbag VALUES (3, 'Gucci', 'Dionysus GG Supreme', 'Beige', 'Excellent', 'GG Supreme canvas shoulder bag with tiger-head clasp', 'GUC003456');
INSERT INTO Handbag VALUES (4, 'Prada', 'Galleria Saffiano', 'Black', 'Good', 'Structured Saffiano leather tote with gold-tone hardware', 'PRA004567');
INSERT INTO Handbag VALUES (5, 'Hermès', 'Birkin 30', 'Gold', 'Excellent', 'Classic Birkin handbag in leather with palladium hardware', 'HER005678');
INSERT INTO Handbag VALUES (6, 'Dior', 'Lady Dior', 'Black', 'Very Good', 'Iconic Cannage-quilted handbag with silver-tone hardware', 'DIO006789');
INSERT INTO Handbag VALUES (7, 'Fendi', 'Baguette', 'Brown', 'Good', 'Iconic compact shoulder bag with FF motif', 'FEN007890');
INSERT INTO Handbag VALUES (8, 'Saint Laurent', 'Loulou Medium', 'Black', 'Excellent', 'Quilted leather shoulder bag with YSL logo', 'YSL008901');
INSERT INTO Handbag VALUES (9, 'Bottega Veneta', 'Cassette', 'Green', 'Very Good', 'Padded intrecciato leather crossbody bag', 'BOT009012');
INSERT INTO Handbag VALUES (10, 'Balenciaga', 'Hourglass Small', 'White', 'Excellent', 'Structured handbag with distinctive curved silhouette', 'BAL010123');
INSERT INTO Handbag VALUES (11, 'Celine', 'Triomphe Shoulder Bag', 'Tan', 'Excellent', 'Leather shoulder bag featuring the Triomphe clasp', 'CEL011234');
INSERT INTO Handbag VALUES (12, 'Burberry', 'Freya Tote', 'Beige', 'Very Good', 'Medium check-pattern canvas and leather tote', 'BUR012345');
INSERT INTO Handbag VALUES (13, 'Givenchy', 'Antigona Medium', 'Black', 'Good', 'Structured leather handbag with top handles', 'GIV013456');
INSERT INTO Handbag VALUES (14, 'Loewe', 'Puzzle Bag Small', 'Tan', 'Excellent', 'Geometric leather bag with distinctive Puzzle construction', 'LOE014567');
INSERT INTO Handbag VALUES (15, 'Valentino Garavani', 'Rockstud Spike', 'Red', 'Very Good', 'Quilted leather shoulder bag with signature Rockstud details', 'VAL015678');

INSERT INTO Listing VALUES (1, 1, 1, 5200.00, DATE '2026-09-01', 'Available', 'Toronto, ON');
INSERT INTO Listing VALUES (2, 2, 2, 1800.00, DATE '2026-09-02', 'Available', 'Markham, ON');
INSERT INTO Listing VALUES (3, 3, 3, 1450.00, DATE '2026-09-03', 'Sold', 'Brampton, ON');
INSERT INTO Listing VALUES (4, 4, 4, 2100.00, DATE '2026-09-04', 'Available', 'Toronto, ON');
INSERT INTO Listing VALUES (5, 5, 5, 12500.00, DATE '2026-09-05', 'Available', 'Mississauga, ON');
INSERT INTO Listing VALUES (6, 6, 6, 3800.00, DATE '2026-09-06', 'Sold', 'Toronto, ON');
INSERT INTO Listing VALUES (7, 7, 7, 1650.00, DATE '2026-09-07', 'Available', 'Vaughan, ON');
INSERT INTO Listing VALUES (8, 8, 8, 1950.00, DATE '2026-09-08', 'Available', 'Toronto, ON');
INSERT INTO Listing VALUES (9, 9, 9, 3200.00, DATE '2026-09-09', 'Available', 'Richmond Hill, ON');
INSERT INTO Listing VALUES (10, 10, 10, 1750.00, DATE '2026-09-10', 'Sold', 'Brampton, ON');
INSERT INTO Listing VALUES (11, 11, 11, 2800.00, DATE '2026-09-11', 'Available', 'Toronto, ON');
INSERT INTO Listing VALUES (12, 12, 12, 1100.00, DATE '2026-09-12', 'Available', 'Mississauga, ON');
INSERT INTO Listing VALUES (13, 13, 13, 2300.00, DATE '2026-09-13', 'Sold', 'Toronto, ON');
INSERT INTO Listing VALUES (14, 14, 14, 3000.00, DATE '2026-09-14', 'Available', 'Oakville, ON');
INSERT INTO Listing VALUES (15, 15, 15, 2400.00, DATE '2026-09-15', 'Available', 'Toronto, ON');

INSERT INTO Authentication VALUES (1, 1, 'Authenticated', DATE '2026-08-01', 'Brand Boutique Verification', 'CERT-CHN-001');
INSERT INTO Authentication VALUES (2, 2, 'Authenticated', DATE '2026-08-03', 'Entrupy Digital Authentication', 'CERT-LV-002');
INSERT INTO Authentication VALUES (3, 3, 'Authenticated', DATE '2026-08-05', 'Professional Authenticator Review', 'CERT-GUC-003');
INSERT INTO Authentication VALUES (4, 4, 'Pending', DATE '2026-09-01', 'Professional Authenticator Review', 'CERT-PRA-004');
INSERT INTO Authentication VALUES (5, 5, 'Authenticated', DATE '2026-07-15', 'Brand Boutique Verification', 'CERT-HER-005');
INSERT INTO Authentication VALUES (6, 6, 'Authenticated', DATE '2026-08-10', 'Entrupy Digital Authentication', 'CERT-DIO-006');
INSERT INTO Authentication VALUES (7, 7, 'Not Authenticated', DATE '2026-08-15', 'Professional Authenticator Review', 'CERT-FEN-007');
INSERT INTO Authentication VALUES (8, 8, 'Authenticated', DATE '2026-08-20', 'Entrupy Digital Authentication', 'CERT-YSL-008');
INSERT INTO Authentication VALUES (9, 9, 'Pending', DATE '2026-09-05', 'Professional Authenticator Review', 'CERT-BOT-009');
INSERT INTO Authentication VALUES (10, 10, 'Authenticated', DATE '2026-08-25', 'Brand Boutique Verification', 'CERT-BAL-010');
INSERT INTO Authentication VALUES (11, 11, 'Authenticated', DATE '2026-08-28', 'Professional Authenticator Review', 'CERT-CEL-011');
INSERT INTO Authentication VALUES (12, 12, 'Not Authenticated', DATE '2026-09-02', 'Entrupy Digital Authentication', 'CERT-BUR-012');
INSERT INTO Authentication VALUES (13, 13, 'Authenticated', DATE '2026-09-04', 'Professional Authenticator Review', 'CERT-GIV-013');
INSERT INTO Authentication VALUES (14, 14, 'Pending', DATE '2026-09-08', 'Entrupy Digital Authentication', 'CERT-LOE-014');
INSERT INTO Authentication VALUES (15, 15, 'Authenticated', DATE '2026-09-10', 'Brand Boutique Verification', 'CERT-VAL-015');

INSERT INTO ShoppingCart VALUES (1, 1, DATE '2026-09-16', 'Active');
INSERT INTO ShoppingCart VALUES (2, 3, DATE '2026-09-17', 'Active');
INSERT INTO ShoppingCart VALUES (3, 5, DATE '2026-09-18', 'Checked Out');
INSERT INTO ShoppingCart VALUES (4, 7, DATE '2026-09-19', 'Active');
INSERT INTO ShoppingCart VALUES (5, 9, DATE '2026-09-20', 'Abandoned');

INSERT INTO CartItem VALUES (1, 1, 2, 1, 1800.00);
INSERT INTO CartItem VALUES (2, 1, 7, 1, 1650.00);
INSERT INTO CartItem VALUES (3, 2, 4, 1, 2100.00);
INSERT INTO CartItem VALUES (4, 2, 8, 1, 1950.00);
INSERT INTO CartItem VALUES (5, 3, 1, 1, 5200.00);
INSERT INTO CartItem VALUES (6, 4, 12, 1, 1100.00);
INSERT INTO CartItem VALUES (7, 5, 15, 1, 2400.00);

INSERT INTO OrderTotal VALUES (1800.00, 234.00, 25.00, 2059.00);
INSERT INTO OrderTotal VALUES (1650.00, 214.50, 20.00, 1884.50);
INSERT INTO OrderTotal VALUES (5200.00, 676.00, 25.00, 5901.00);

INSERT INTO Orders VALUES (1, 1, DATE '2026-10-14', 'Shipped', 1800.00, 234.00, 25.00, 'Toronto, ON', 'Toronto, ON');
INSERT INTO Orders VALUES (2, 3, DATE '2026-10-15', 'Confirmed', 1650.00, 214.50, 20.00, 'Brampton, ON', 'Brampton, ON');
INSERT INTO Orders VALUES (3, 5, DATE '2026-10-16', 'Delivered', 5200.00, 676.00, 25.00, 'Mississauga, ON', 'Mississauga, ON');

/* >>>>>>>>>> NEW: ORDERITEM ROWS <<<<<<<<<<
   Each order's Subtotal equals the price of exactly one listing, and the seller matches the Shipping row:
   Order 1 = Listing 2 ($1800, seller 2), Order 2 = Listing 7 ($1650, seller 7), Order 3 = Listing 1 ($5200, seller 1). */
INSERT INTO OrderItem VALUES (1, 1, 2);
INSERT INTO OrderItem VALUES (2, 2, 7);
INSERT INTO OrderItem VALUES (3, 3, 1);
/* Those three listings have been bought, so mark them Sold (otherwise the site would let someone buy them again) */
UPDATE Listing SET AvailabilityStatus = 'Sold' WHERE ListingID IN (1, 2, 7);

INSERT INTO Payment VALUES (1, 1, 2059.00, 'Credit Card', DATE '2026-10-14', 'Completed', 'TXN001');
INSERT INTO Payment VALUES (2, 2, 1884.50, 'PayPal', DATE '2026-10-15', 'Completed', 'TXN002');
INSERT INTO Payment VALUES (3, 3, 5901.00, 'Credit Card', DATE '2026-10-16', 'Completed', 'TXN003');

INSERT INTO Shipping VALUES (1, 1, 2, 'Canada Post', 'CP10001', 'Toronto, ON', DATE '2026-10-20', 'Shipped');
INSERT INTO Shipping VALUES (2, 2, 7, 'FedEx', 'FD10002', 'Brampton, ON', DATE '2026-10-21', 'On Route');
INSERT INTO Shipping VALUES (3, 3, 1, 'UPS', 'UPS10003', 'Mississauga, ON', DATE '2026-10-19', 'Delivered');

INSERT INTO Review VALUES (1, 5, 1, 5, 'Beautiful Chanel handbag. Excellent quality.', DATE '2026-10-20');
INSERT INTO Review VALUES (2, 3, 2, 4, 'The handbag arrived in great condition.', DATE '2026-10-21');
INSERT INTO Review VALUES (3, 1, 6, 5, 'Very satisfied with the purchase.', DATE '2026-10-22');
INSERT INTO Review VALUES (4, 7, 3, 3, 'Good handbag, but delivery was slower than expected.', DATE '2026-10-23');
INSERT INTO Review VALUES (5, 9, 10, 4, 'Nice handbag and good packaging.', DATE '2026-10-24');

INSERT INTO Wishlist VALUES (1, 1, DATE '2026-09-20');
INSERT INTO Wishlist VALUES (2, 3, DATE '2026-09-21');
INSERT INTO Wishlist VALUES (3, 5, DATE '2026-09-22');
INSERT INTO Wishlist VALUES (4, 7, DATE '2026-09-23');
INSERT INTO Wishlist VALUES (5, 9, DATE '2026-09-24');

INSERT INTO WishlistItem VALUES (1, 1, 2, DATE '2026-09-25');
INSERT INTO WishlistItem VALUES (2, 1, 5, DATE '2026-09-26');
INSERT INTO WishlistItem VALUES (3, 2, 1, DATE '2026-09-27');
INSERT INTO WishlistItem VALUES (4, 2, 8, DATE '2026-09-28');
INSERT INTO WishlistItem VALUES (5, 3, 4, DATE '2026-09-29');
INSERT INTO WishlistItem VALUES (6, 3, 9, DATE '2026-09-30');
INSERT INTO WishlistItem VALUES (7, 4, 11, DATE '2026-10-01');
INSERT INTO WishlistItem VALUES (8, 5, 14, DATE '2026-10-02');

COMMIT;

/* >>>>>>>>>> NEW: SEQUENCES <<<<<<<<<<
   Your ID columns are plain NUMBERs, so the website needs counters to hand out new IDs
   for new users, listings, orders and so on. Each one starts just after your existing rows. */
CREATE SEQUENCE users_seq        START WITH 16;
CREATE SEQUENCE handbag_seq      START WITH 16;
CREATE SEQUENCE listing_seq      START WITH 16;
CREATE SEQUENCE auth_seq         START WITH 16;
CREATE SEQUENCE cart_seq         START WITH 6;
CREATE SEQUENCE cartitem_seq     START WITH 8;
CREATE SEQUENCE orders_seq       START WITH 4;
CREATE SEQUENCE orderitem_seq    START WITH 4;
CREATE SEQUENCE payment_seq      START WITH 4;
CREATE SEQUENCE shipping_seq     START WITH 4;
CREATE SEQUENCE review_seq       START WITH 6;
CREATE SEQUENCE wishlist_seq     START WITH 6;
CREATE SEQUENCE wishlistitem_seq START WITH 9;
