{{ config(materialized='incremental', unique_key='id', partition_by='fake_date', cluster_by='id' ) }}
{# clustering helps a lot with MERGE costs #}

SELECT author, score, TIMESTAMP_SECONDS(created_utc) ts, parent_id, link_id, controversiality, id, body, DATE('2000-01-01') fake_date
FROM {{ source('reddit_comments', '20*') }}
WHERE subreddit = 'AmItheAsshole'
AND _table_suffix > '19_'

{% if is_incremental() -%}
AND _table_suffix > (SELECT FORMAT_TIMESTAMP('%y_%m', MAX(ts)) from {{ this }})
{%- endif -%}
