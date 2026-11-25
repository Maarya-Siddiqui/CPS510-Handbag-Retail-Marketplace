import os
from contextlib import asynccontextmanager
from typing import Optional

import oracledb
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware

load_dotenv()

DB_USER = os.getenv("ORACLE_USER", "marketplace")
DB_PASSWORD = os.getenv("ORACLE_PASSWORD", "")
DB_DSN = os.getenv("ORACLE_DSN", "localhost:1521/FREEPDB1")
POOL_MIN = int(os.getenv("POOL_MIN", "1"))
POOL_MAX = int(os.getenv("POOL_MAX", "5"))

pool = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    global pool
    if DB_PASSWORD:
        pool = oracledb.create_pool(
            user=DB_USER,
            password=DB_PASSWORD,
            dsn=DB_DSN,
            min=POOL_MIN,
            max=POOL_MAX,
            increment=1,
        )
    yield
    if pool is not None:
        pool.close()

app = FastAPI(title="Maison Archive Marketplace API", version="1.0.0", lifespan=lifespan)

# For local development only. Restrict allow_origins to your deployed frontend domain later.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://127.0.0.1:5500", "http://localhost:5500", "http://127.0.0.1:8000"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["*"],
)

def get_pool():
    if pool is None:
        raise HTTPException(
            status_code=503,
            detail="Oracle pool is not configured. Check ORACLE_USER, ORACLE_PASSWORD and ORACLE_DSN in backend/.env.",
        )
    return pool

@app.get("/api/health")
def health():
    try:
        p = get_pool()
        with p.acquire() as connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1 FROM DUAL")
                cursor.fetchone()
        return {"status": "ok", "database": "connected"}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Database connection failed: {exc}")

@app.get("/api/listings")
def list_listings(
    search: Optional[str] = Query(default=None, max_length=100),
    condition: Optional[str] = Query(default=None, max_length=40),
    sort: str = Query(default="newest", pattern="^(newest|price_asc|price_desc)$"),
):
    """
    Uses the documented Listing + Handbag relationship.
    The supplied schema does not include a handbag image column, so image_url is null.
    Add an ImageURL column or a HandbagImage table when you implement image uploads.
    """
    p = get_pool()
    sql = """
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
    """
    binds = {}
    if search:
        sql += """
          AND (
            UPPER(h.Designer) LIKE :search
            OR UPPER(h.ModelName) LIKE :search
            OR UPPER(h.Colour) LIKE :search
          )
        """
        binds["search"] = f"%{search.upper()}%"
    if condition:
        sql += " AND UPPER(h.HandbagCondition) = UPPER(:condition)"
        binds["condition"] = condition
    if sort == "price_asc":
        sql += " ORDER BY l.Price ASC"
    elif sort == "price_desc":
        sql += " ORDER BY l.Price DESC"
    else:
        sql += " ORDER BY l.ListingDate DESC NULLS LAST"

    try:
        with p.acquire() as connection:
            with connection.cursor() as cursor:
                cursor.execute(sql, binds)
                columns = [d[0].lower() for d in cursor.description]
                rows = [dict(zip(columns, row)) for row in cursor.fetchall()]
        # Convert Oracle Decimal/date values into JSON-friendly values.
        result = []
        for row in rows:
            clean = {}
            for key, value in row.items():
                if hasattr(value, "isoformat"):
                    clean[key] = value.isoformat()
                elif value is not None and value.__class__.__name__ == "Decimal":
                    clean[key] = float(value)
                else:
                    clean[key] = value
            clean["image_url"] = None
            result.append(clean)
        return result
    except oracledb.Error as exc:
        raise HTTPException(status_code=500, detail=f"Oracle query failed: {exc}")

@app.get("/api/listings/{listing_id}")
def get_listing(listing_id: int):
    p = get_pool()
    sql = """
        SELECT
            l.ListingID, l.HandbagID, l.UserID AS SellerID, l.Price,
            l.ListingDate, l.AvailabilityStatus, l.PickupLocation,
            h.Designer, h.ModelName, h.Colour, h.HandbagCondition, h.Description
        FROM Listing l
        JOIN Handbag h ON h.HandbagID = l.HandbagID
        WHERE l.ListingID = :listing_id
    """
    try:
        with p.acquire() as connection:
            with connection.cursor() as cursor:
                cursor.execute(sql, {"listing_id": listing_id})
                row = cursor.fetchone()
                if row is None:
                    raise HTTPException(status_code=404, detail="Listing not found")
                columns = [d[0].lower() for d in cursor.description]
                result = dict(zip(columns, row))
        for key, value in list(result.items()):
            if hasattr(value, "isoformat"):
                result[key] = value.isoformat()
            elif value is not None and value.__class__.__name__ == "Decimal":
                result[key] = float(value)
        result["image_url"] = None
        return result
    except HTTPException:
        raise
    except oracledb.Error as exc:
        raise HTTPException(status_code=500, detail=f"Oracle query failed: {exc}")
