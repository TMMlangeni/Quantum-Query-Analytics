--Create tables 
-- 1. pricing_surge_zones
CREATE TABLE IF NOT EXISTS pricing_surge_zones (
    zone_id          VARCHAR(50) PRIMARY KEY,
    zone_name        VARCHAR(100),
    city             VARCHAR(50),
    base_fare_zar    NUMERIC(10, 2),
    per_km_rate_zar  NUMERIC(10, 2),
    per_min_rate_zar NUMERIC(10, 2)
);

-- 2. sa_riders
CREATE TABLE IF NOT EXISTS sa_riders (
    rider_id              VARCHAR(30) PRIMARY KEY,
    first_name            VARCHAR(50),
    last_name             VARCHAR(50),
    mobile_number         VARCHAR(25),
    home_city             VARCHAR(50),
    province              VARCHAR(50),
    preferred_payment     VARCHAR(30),
    account_created_date  DATE
);

-- 3. sa_drivers
CREATE TABLE IF NOT EXISTS sa_drivers (
    driver_id                VARCHAR(30) PRIMARY KEY,
    first_name               VARCHAR(50),
    last_name                VARCHAR(50),
    operating_city           VARCHAR(50),
    platform_affiliation     VARCHAR(50),
    platform_commission_pct  NUMERIC(5, 4),
    driver_rating            NUMERIC(3, 2),
    total_lifetime_trips     INTEGER,
    onboarding_date          DATE
);

-- 4. vehicles
CREATE TABLE IF NOT EXISTS vehicles (
    vehicle_id     VARCHAR(50),
    driver_id      VARCHAR(30),
    make           VARCHAR(50),
    model          VARCHAR(50),
    year           INTEGER,
    license_plate  VARCHAR(30),
    category_type  VARCHAR(60)
);

-- 5. trip_headers
CREATE TABLE IF NOT EXISTS trip_headers (
    trip_id              VARCHAR(40),
    rider_id             VARCHAR(30),
    driver_id            VARCHAR(30),
    zone_id              VARCHAR(50),
    ride_category        VARCHAR(60),
    request_timestamp    TIMESTAMP,
    trip_status          VARCHAR(40),
    cancellation_reason  VARCHAR(60)
);

-- 6. trip_fare_breakdown
CREATE TABLE IF NOT EXISTS trip_fare_breakdown (
    trip_id                  VARCHAR(40),
    distance_km              NUMERIC(8, 2),
    duration_minutes         INTEGER,
    surge_multiplier         NUMERIC(4, 2),
    base_fare_zar            NUMERIC(10, 2),
    tolls_zar                NUMERIC(10, 2),
    tip_zar                  NUMERIC(10, 2),
    total_fare_zar           NUMERIC(10, 2),
    platform_commission_zar  NUMERIC(10, 2),
    driver_payout_zar        NUMERIC(10, 2),
    payment_method           VARCHAR(40)
);

-- 7. trip_reviews
CREATE TABLE IF NOT EXISTS trip_reviews (
    review_id               VARCHAR(30),
    trip_id                 VARCHAR(40),
    rider_rating_of_driver  SMALLINT,
    driver_rating_of_rider  SMALLINT,
    feedback_comment        TEXT
);

--Adding Primary Keys
ALTER TABLE vehicles
    ADD CONSTRAINT pk_vehicles PRIMARY KEY (vehicle_id);

ALTER TABLE trip_headers
    ADD CONSTRAINT pk_trip_headers PRIMARY KEY (trip_id);

ALTER TABLE trip_fare_breakdown
    ADD CONSTRAINT pk_trip_fare_breakdown PRIMARY KEY (trip_id);                         -- PK + FK (1:1 with trip_headers)

ALTER TABLE trip_reviews
    ADD CONSTRAINT pk_trip_reviews PRIMARY KEY (review_id);

--Adding Constraints
ALTER TABLE vehicles
    ADD CONSTRAINT uq_vehicles_driver_id UNIQUE (driver_id),                           -- FK,AK: one vehicle per driver
    ADD CONSTRAINT uq_vehicles_license_plate UNIQUE (license_plate);                     -- AK

ALTER TABLE trip_reviews
    ADD CONSTRAINT uq_trip_reviews_trip_id UNIQUE (trip_id);   

--Adding Foreign Keys
ALTER TABLE vehicles
    ADD CONSTRAINT fk_vehicles_driver
    FOREIGN KEY (driver_id) REFERENCES sa_drivers (driver_id);

ALTER TABLE trip_headers
    ADD CONSTRAINT fk_trip_headers_rider
    FOREIGN KEY (rider_id) REFERENCES sa_riders (rider_id);

ALTER TABLE trip_headers
    ADD CONSTRAINT fk_trip_headers_driver
    FOREIGN KEY (driver_id) REFERENCES sa_drivers (driver_id);

ALTER TABLE trip_headers
    ADD CONSTRAINT fk_trip_headers_zone
    FOREIGN KEY (zone_id) REFERENCES pricing_surge_zones (zone_id);

ALTER TABLE trip_fare_breakdown
    ADD CONSTRAINT fk_fare_breakdown_trip
    FOREIGN KEY (trip_id) REFERENCES trip_headers (trip_id);

ALTER TABLE trip_reviews
    ADD CONSTRAINT fk_trip_reviews_trip
    FOREIGN KEY (trip_id) REFERENCES trip_headers (trip_id);




--PERFORMANCE SET-UP
 
-- Covering indexes: every column the queries read is inside the index,
-- So PostgreSQL can use an Index Only Scan and skip the table heap.
CREATE INDEX IF NOT EXISTS idx_drivers_city_rating
    ON sa_drivers (operating_city) INCLUDE (driver_id, driver_rating);
 
CREATE INDEX IF NOT EXISTS idx_vehicles_driver_cover
    ON vehicles (driver_id) INCLUDE (make, year);
 
-- Only needed for the trip-level (Version B) queries:
CREATE INDEX IF NOT EXISTS idx_trip_headers_driver
    ON trip_headers (driver_id);
 
-- Refresh optimizer statistics (the PostgreSQL form of
-- "ANALYZE TABLE ... COMPUTE STATISTICS" from the slides).
ANALYZE sa_drivers;
ANALYZE vehicles;
ANALYZE trip_headers;
ANALYZE trip_reviews;
 
-- NOTE: no index on make or category_type alone. They have low sparsity (few distinct values), so an index there is rarely used.

--===================================================================================

/* =====================================================================
   QUESTION 1 - Regional Vehicle Make Performance Benchmarking
   (kept: Q1-B - ranks makes per city AND compares each to the city baseline)
   ===================================================================== */
WITH make_city AS (
    SELECT
        d.operating_city      AS city,
        v.make,
        COUNT(*)              AS n,
        SUM(d.driver_rating)  AS rating_sum
    FROM sa_drivers d
    JOIN vehicles v ON v.driver_id = d.driver_id
    WHERE d.driver_rating IS NOT NULL
    GROUP BY d.operating_city, v.make
),
scored AS (
    SELECT
        city,
        make,
        n,
        rating_sum / n                                          AS make_avg,
        SUM(rating_sum) OVER (PARTITION BY city)
          / SUM(n)      OVER (PARTITION BY city)                AS city_baseline
    FROM make_city
)
SELECT
    city,
    make,
    n                                          AS driver_count,
    ROUND(make_avg, 3)                         AS make_avg_rating,
    ROUND(city_baseline, 3)                    AS city_baseline,
    ROUND(make_avg - city_baseline, 3)         AS gap_vs_baseline,
    ROUND(n * (make_avg - city_baseline), 2)   AS rating_points_impact,
    RANK() OVER (PARTITION BY city ORDER BY make_avg DESC) AS rank_in_city,
    CASE WHEN make_avg < city_baseline
         THEN 'BELOW BASELINE' ELSE 'AT/ABOVE BASELINE' END AS status
FROM scored
WHERE n >= 5                -- the baseline above still uses ALL makes
ORDER BY city, rank_in_city;
 
 
/* =====================================================================
   QUESTION 2 - Asset Age Cut-off and Passenger Satisfaction
   (kept: Q2-A - rating per age bracket 0-2, 3-5, 6-8, 9+ with step change)
   ===================================================================== */
WITH aged AS (
    SELECT
        d.driver_rating,
        CASE
            WHEN EXTRACT(YEAR FROM CURRENT_DATE)::INT - v.year <= 2 THEN 1
            WHEN EXTRACT(YEAR FROM CURRENT_DATE)::INT - v.year <= 5 THEN 2
            WHEN EXTRACT(YEAR FROM CURRENT_DATE)::INT - v.year <= 8 THEN 3
            ELSE 4
        END AS bracket_no
    FROM vehicles   v
    JOIN sa_drivers d ON d.driver_id = v.driver_id
    WHERE d.driver_rating IS NOT NULL
      AND v.year IS NOT NULL
),
stats AS (
    SELECT
        bracket_no,
        COUNT(*)           AS driver_count,
        SUM(driver_rating) AS rating_sum,
        MIN(driver_rating) AS min_rating,
        MAX(driver_rating) AS max_rating
    FROM aged
    GROUP BY bracket_no
) SELECT
    CASE bracket_no
        WHEN 1 THEN '0-2 years'
        WHEN 2 THEN '3-5 years'
        WHEN 3 THEN '6-8 years'
        ELSE        '9+ years'
    END                                                         AS age_bracket,
    driver_count,
    ROUND(rating_sum / driver_count, 3)                         AS avg_driver_rating,
    ROUND(rating_sum / driver_count
          - LAG(rating_sum / driver_count) OVER (ORDER BY bracket_no), 3)
                                                                AS change_vs_prev_bracket,
    ROUND(rating_sum / driver_count
          - SUM(rating_sum) OVER () / SUM(driver_count) OVER (), 3)
                                                                AS gap_vs_fleet_avg,
    min_rating,
    max_rating
FROM stats
ORDER BY bracket_no;


/* =====================================================================
   QUESTION 3 - Platform market share & dual vs. exclusive driver longevity
   (only one query existed)
   ===================================================================== */
WITH market_share AS (
    SELECT
        operating_city,
        platform_affiliation,
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY operating_city) AS market_share_percentage
    FROM sa_drivers
    GROUP BY operating_city, platform_affiliation
),
city_averages AS (
    SELECT
        operating_city,
        AVG(CASE WHEN platform_affiliation = 'Dual-Platform (Both)' THEN total_lifetime_trips END) AS avg_dual_trips,
        AVG(CASE WHEN platform_affiliation = 'Uber' THEN total_lifetime_trips END) AS avg_uber_trips,
        AVG(CASE WHEN platform_affiliation = 'Bolt' THEN total_lifetime_trips END) AS avg_bolt_trips,
        AVG(CASE WHEN platform_affiliation != 'Dual-Platform (Both)' THEN total_lifetime_trips END) AS avg_exclusive_trips
    FROM sa_drivers
    GROUP BY operating_city
)
SELECT
    ms.operating_city,
    ms.platform_affiliation,
    ROUND(ms.market_share_percentage, 2) AS market_share_percentage,
    ROUND(ca.avg_dual_trips, 2) AS avg_dual_trips,
    ROUND(ca.avg_uber_trips, 2) AS avg_uber_trips,
    ROUND(ca.avg_bolt_trips, 2) AS avg_bolt_trips,
    ROUND(ca.avg_exclusive_trips, 2) AS avg_exclusive_trips,
    CASE
        WHEN ca.avg_dual_trips > ca.avg_exclusive_trips THEN 'Dual Outperforms Exclusive'
        WHEN ca.avg_dual_trips < ca.avg_exclusive_trips THEN 'Exclusive Outperforms Dual'
        ELSE 'Equal Longevity'
    END AS longevity_comparison
FROM market_share ms
JOIN city_averages ca ON ms.operating_city = ca.operating_city
ORDER BY ms.operating_city, ms.platform_affiliation;


 
/* =====================================================================
   QUESTION 4 - Vehicle Age & Category Influence on Rider Tipping Behavior
   (kept: Q4A - aggregated tip % by age bracket and ride category; duplicate removed)
   ===================================================================== */
WITH trip_tips_derived AS (
    SELECT
        th.trip_id,
        th.driver_id,
        th.ride_category,
        EXTRACT(YEAR FROM CURRENT_DATE) - v.year AS vehicle_age_years,
        CASE
            WHEN (EXTRACT(YEAR FROM CURRENT_DATE) - v.year) <= 3 THEN '1. 0-3 Years (New)'
            WHEN (EXTRACT(YEAR FROM CURRENT_DATE) - v.year) BETWEEN 4 AND 7 THEN '2. 4-7 Years (Mid-Age)'
            ELSE '3. 8+ Years (Aging)'
        END AS vehicle_age_bracket,
        tf.tip_zar,
        tf.total_fare_zar,
        (tf.tip_zar / NULLIF(tf.total_fare_zar, 0)) * 100 AS tip_pct
    FROM trip_headers th
    INNER JOIN trip_fare_breakdown tf ON th.trip_id = tf.trip_id
    INNER JOIN vehicles v ON th.driver_id = v.driver_id
    WHERE th.trip_status = 'COMPLETED'
      AND tf.total_fare_zar > 0
)
SELECT
    d.platform_affiliation,
    tt.ride_category,
    tt.vehicle_age_bracket,
    COUNT(tt.trip_id) AS total_completed_trips,
    ROUND(CAST(AVG(tt.tip_zar) AS NUMERIC), 2) AS avg_tip_zar,
    ROUND(CAST(AVG(tt.tip_pct) AS NUMERIC), 2) AS avg_tip_percentage
FROM trip_tips_derived tt
INNER JOIN sa_drivers d ON tt.driver_id = d.driver_id
GROUP BY
    d.platform_affiliation,
    tt.ride_category,
    tt.vehicle_age_bracket
ORDER BY
    d.platform_affiliation,
    tt.ride_category,
    tt.vehicle_age_bracket;
 
 
/* =====================================================================
   QUESTION 5 - Platform Commission vs. Fleet Quality
   (only one query existed)
   ===================================================================== */
SELECT
    d.platform_affiliation,
    ROUND(AVG(d.platform_commission_pct) * 100, 1) || '%' AS avg_commission_pct,
    COUNT(DISTINCT d.driver_id) AS total_drivers,
    ROUND(AVG(2026 - v.year), 1) AS avg_vehicle_age,
    ROUND(AVG(d.driver_rating), 2) AS avg_driver_rating
FROM sa_drivers d
JOIN vehicles v ON d.driver_id = v.driver_id
WHERE d.driver_rating IS NOT NULL
GROUP BY d.platform_affiliation
ORDER BY avg_commission_pct DESC;











 
