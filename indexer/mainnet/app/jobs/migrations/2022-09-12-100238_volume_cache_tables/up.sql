INSERT INTO collection_trends (COLLECTION)
    select distinct collection_address as collection from metadata_collection_keys on conflict do nothing;

INSERT INTO collection_trends (COLLECTION)
    select distinct id::text as collection from me_collections on conflict do nothing;