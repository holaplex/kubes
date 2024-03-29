-- update floor price for mcc
WITH floor_price_table AS (
    SELECT
        metadata_collection_keys.collection_address AS collection,
        min(listings.price) AS floor_price
    FROM
        listings
        INNER JOIN metadata_collection_keys ON (listings.metadata = metadata_collection_keys.metadata_address)
            AND listings.purchase_id IS NULL
            AND listings.canceled_at IS NULL
            AND metadata_collection_keys.verified = TRUE
            AND listings.marketplace_program = 'M2mx93ekt1fmXSVkTrUL9xVFHkmME8HTUi5Cyc5aF7K'
    GROUP BY
        metadata_collection_keys.collection_address)
UPDATE
    COLLECTION_TRENDS
SET
    FLOOR_PRICE = f.floor_price
FROM
    floor_price_table f
    INNER JOIN COLLECTION_TRENDS CV ON f.COLLECTION = CV.COLLECTION
WHERE
    COLLECTION_TRENDS.collection = CV.collection;

--update prev_1d_floor_price for mcc
WITH floor_price_table AS (
    SELECT
        metadata_collection_keys.collection_address AS collection,
        min(listings.price) AS floor_price
    FROM
        listings
        INNER JOIN metadata_collection_keys ON (listings.metadata = metadata_collection_keys.metadata_address)
            AND listings.purchase_id IS NULL
            AND listings.canceled_at IS NULL
            AND metadata_collection_keys.verified = TRUE
            AND listings.marketplace_program = 'M2mx93ekt1fmXSVkTrUL9xVFHkmME8HTUi5Cyc5aF7K'
    WHERE
         listings.CREATED_AT <= (NOW() - INTERVAL '1 days')
    GROUP BY
        metadata_collection_keys.collection_address)
UPDATE
    COLLECTION_TRENDS
SET
    PREV_1D_FLOOR_PRICE = f.floor_price
FROM
    floor_price_table f
    INNER JOIN COLLECTION_TRENDS CV ON f.COLLECTION = CV.COLLECTION
WHERE
    COLLECTION_TRENDS.collection = CV.collection;

-- update floor_price for non mcc
WITH floor_price_table AS (
    SELECT
        me_metadata_collections.collection_id::text AS collection,
        min(listings.price) AS floor_price
    FROM
        listings
        INNER JOIN me_metadata_collections ON (listings.metadata = me_metadata_collections.metadata_address)
            AND listings.purchase_id IS NULL
            AND listings.canceled_at IS NULL
            AND listings.marketplace_program = 'M2mx93ekt1fmXSVkTrUL9xVFHkmME8HTUi5Cyc5aF7K'
    GROUP BY
        me_metadata_collections.collection_id)
UPDATE
    COLLECTION_TRENDS
SET
    floor_price = f.floor_price
FROM
    floor_price_table f
    INNER JOIN COLLECTION_TRENDS CV ON f.COLLECTION = CV.COLLECTION
WHERE
    COLLECTION_TRENDS.collection = CV.collection;

-- update _prev_1d_floor_price for non mcc
WITH floor_price_table AS (
    SELECT
        me_metadata_collections.collection_id::text AS collection,
        min(listings.price) AS floor_price
    FROM
        listings
        INNER JOIN me_metadata_collections ON (listings.metadata = me_metadata_collections.metadata_address)
            AND listings.purchase_id IS NULL
            AND listings.canceled_at IS NULL
            AND listings.marketplace_program = 'M2mx93ekt1fmXSVkTrUL9xVFHkmME8HTUi5Cyc5aF7K'
    WHERE
        listings.CREATED_AT <= (NOW() - INTERVAL '1 days')
    GROUP BY
        me_metadata_collections.collection_id)
UPDATE
    COLLECTION_TRENDS
SET
    PREV_1D_FLOOR_PRICE = f.floor_price
FROM
    floor_price_table f
    INNER JOIN COLLECTION_TRENDS CV ON f.COLLECTION = CV.COLLECTION
WHERE
    COLLECTION_TRENDS.collection = CV.collection;

-- update _1d_sales_count for mcc
WITH sales_count AS (
    SELECT
        metadata_collection_keys.collection_address AS collection,
        count(purchases.id) AS sales_count
    FROM
        purchases
        INNER JOIN metadata_collection_keys ON (purchases.metadata = metadata_collection_keys.metadata_address)
    WHERE
        metadata_collection_keys.verified = TRUE
        AND purchases.marketplace_program = 'M2mx93ekt1fmXSVkTrUL9xVFHkmME8HTUi5Cyc5aF7K'
        AND purchases.CREATED_AT >= (NOW() - INTERVAL '1 days')
    GROUP BY
        metadata_collection_keys.collection_address)
UPDATE
    COLLECTION_TRENDS
SET
    _1D_SALES_COUNT = s.sales_count
FROM
    sales_count s
    INNER JOIN COLLECTION_TRENDS CV ON s.COLLECTION = CV.COLLECTION
WHERE
    COLLECTION_TRENDS.collection = CV.collection;

-- update prev_1d_sales_count for mcc
WITH sales_count AS (
    SELECT
        metadata_collection_keys.collection_address AS collection,
        count(purchases.id) AS sales_count
    FROM
        purchases
        INNER JOIN metadata_collection_keys ON (purchases.metadata = metadata_collection_keys.metadata_address)
    WHERE
        metadata_collection_keys.verified = TRUE
        AND purchases.marketplace_program = 'M2mx93ekt1fmXSVkTrUL9xVFHkmME8HTUi5Cyc5aF7K'
        AND purchases.CREATED_AT >= (NOW() - INTERVAL '2 days')
        AND purchases.CREATED_AT <= (NOW() - INTERVAL '1 days')
    GROUP BY
        metadata_collection_keys.collection_address)
UPDATE
    COLLECTION_TRENDS
SET
    PREV_1D_SALES_COUNT = s.sales_count
FROM
    sales_count s
    INNER JOIN COLLECTION_TRENDS CV ON s.COLLECTION = CV.COLLECTION
WHERE
    COLLECTION_TRENDS.collection = CV.collection;

-- update _1d_sales_count for non_mcc
WITH sales_count AS (
    SELECT
        me_metadata_collections.collection_id::text AS collection,
        count(purchases.id) AS sales_count
    FROM
        purchases
        INNER JOIN me_metadata_collections ON (purchases.metadata = me_metadata_collections.metadata_address)
    WHERE
        purchases.marketplace_program = 'M2mx93ekt1fmXSVkTrUL9xVFHkmME8HTUi5Cyc5aF7K'
        AND purchases.CREATED_AT >= (NOW() - INTERVAL '1 days')
    GROUP BY
        me_metadata_collections.collection_id)
UPDATE
    COLLECTION_TRENDS
SET
    _1D_SALES_COUNT = s.sales_count
FROM
    sales_count s
    INNER JOIN COLLECTION_TRENDS CV ON s.COLLECTION = CV.COLLECTION
WHERE
    COLLECTION_TRENDS.collection = CV.collection;

-- update prev_1d_sales_count for non_mcc
WITH sales_count AS (
    SELECT
        me_metadata_collections.collection_id::text AS collection,
        count(purchases.id) AS sales_count
    FROM
        purchases
        INNER JOIN me_metadata_collections ON (purchases.metadata = me_metadata_collections.metadata_address)
    WHERE
        purchases.marketplace_program = 'M2mx93ekt1fmXSVkTrUL9xVFHkmME8HTUi5Cyc5aF7K'
        AND purchases.CREATED_AT >= (NOW() - INTERVAL '2 days')
        AND purchases.CREATED_AT <= (NOW() - INTERVAL '1 days')
    GROUP BY
        me_metadata_collections.collection_id)
UPDATE
    COLLECTION_TRENDS
SET
    PREV_1D_SALES_COUNT = s.sales_count
FROM
    sales_count s
    INNER JOIN COLLECTION_TRENDS CV ON s.COLLECTION = CV.COLLECTION
WHERE
    COLLECTION_TRENDS.collection = CV.collection;

-- update 1d_marketcap for mcc
WITH marketcaps AS (
    SELECT
        metadata_collection_keys.collection_address AS collection,
        MIN(listings.price)::numeric * count(metadata_collection_keys.metadata_address)::numeric as marketcap
    FROM
        listings
        INNER JOIN metadata_collection_keys ON (listings.metadata = metadata_collection_keys.metadata_address)
            WHERE listings.purchase_id IS NULL
            AND listings.canceled_at IS NULL
            AND listings.CREATED_AT <= (NOW() - INTERVAL '1 days')
            AND listings.marketplace_program = 'M2mx93ekt1fmXSVkTrUL9xVFHkmME8HTUi5Cyc5aF7K'
            GROUP BY metadata_collection_keys.collection_address)
UPDATE
    COLLECTION_TRENDS
SET
    _1D_MARKETCAP = m.marketcap
FROM
    marketcaps m
    INNER JOIN COLLECTION_TRENDS CT ON m.COLLECTION = CT.COLLECTION
WHERE
    COLLECTION_TRENDS.collection = CT.collection;

-- update 1d_marketcap for non mcc
WITH marketcaps AS (
    SELECT
        me_metadata_collections.collection_id::text AS collection,
        MIN(listings.price)::numeric * count(me_metadata_collections.metadata_address)::numeric as marketcap
    FROM
        listings
        INNER JOIN me_metadata_collections ON (listings.metadata = me_metadata_collections.metadata_address)
            WHERE listings.purchase_id IS NULL
            AND listings.canceled_at IS NULL
            AND listings.CREATED_AT <= (NOW() - INTERVAL '1 days')
            AND listings.marketplace_program = 'M2mx93ekt1fmXSVkTrUL9xVFHkmME8HTUi5Cyc5aF7K'
            GROUP BY me_metadata_collections.collection_id)
UPDATE
    COLLECTION_TRENDS
SET
    _1D_MARKETCAP = m.marketcap
FROM
    marketcaps m
    INNER JOIN COLLECTION_TRENDS CT ON m.COLLECTION = CT.COLLECTION
WHERE
    COLLECTION_TRENDS.collection = CT.collection;

-- update prev_1d_marketcap for mcc
WITH marketcaps AS (
    SELECT
        metadata_collection_keys.collection_address AS collection,
        MIN(listings.price)::numeric * count(metadata_collection_keys.metadata_address)::numeric as marketcap
    FROM
        listings
        INNER JOIN metadata_collection_keys ON (listings.metadata = metadata_collection_keys.metadata_address)
            WHERE listings.purchase_id IS NULL
            AND listings.canceled_at IS NULL
            AND listings.CREATED_AT >= (NOW() - INTERVAL '2 days')
            AND listings.CREATED_AT <= (NOW() - INTERVAL '1 days')
            AND listings.marketplace_program = 'M2mx93ekt1fmXSVkTrUL9xVFHkmME8HTUi5Cyc5aF7K'
            GROUP BY metadata_collection_keys.collection_address)
UPDATE
    COLLECTION_TRENDS
SET
    PREV_1D_MARKETCAP = m.marketcap
FROM
    marketcaps m
    INNER JOIN COLLECTION_TRENDS CT ON m.COLLECTION = CT.COLLECTION
WHERE
    COLLECTION_TRENDS.collection = CT.collection;

-- update prev_1d_marketcap for non mcc
WITH marketcaps AS (
    SELECT
        me_metadata_collections.collection_id::text AS collection,
        MIN(listings.price)::numeric * count(me_metadata_collections.metadata_address)::numeric as marketcap
    FROM
        listings
        INNER JOIN me_metadata_collections ON (listings.metadata = me_metadata_collections.metadata_address)
            WHERE listings.purchase_id IS NULL
            AND listings.canceled_at IS NULL
            AND listings.CREATED_AT >= (NOW() - INTERVAL '2 days')
            AND listings.CREATED_AT <= (NOW() - INTERVAL '1 days')
            AND listings.marketplace_program = 'M2mx93ekt1fmXSVkTrUL9xVFHkmME8HTUi5Cyc5aF7K'
            GROUP BY me_metadata_collections.collection_id)
UPDATE
    COLLECTION_TRENDS
SET
    PREV_1D_MARKETCAP = m.marketcap
FROM
    marketcaps m
    INNER JOIN COLLECTION_TRENDS CT ON m.COLLECTION = CT.COLLECTION
WHERE
    COLLECTION_TRENDS.collection = CT.collection;

-- update nft count

with
    nft_count_table as (
        select
            metadata_collection_keys.collection_address as collection,
            count(metadata_collection_keys.metadata_address) as nft_count
        from metadata_collection_keys
        where metadata_collection_keys.verified = true
        group by metadata_collection_keys.collection_address
        union all
        select
            me_metadata_collections.collection_id::text as collection,
            count(me_metadata_collections.metadata_address) as nft_count
        from me_metadata_collections
        group by me_metadata_collections.collection_id
    )
    UPDATE
    COLLECTION_TRENDS
SET
    NFT_COUNT = n.nft_count
FROM
    nft_count_table n
    INNER JOIN COLLECTION_TRENDS CT ON n.COLLECTION = CT.COLLECTION
WHERE
    COLLECTION_TRENDS.collection = CT.collection;