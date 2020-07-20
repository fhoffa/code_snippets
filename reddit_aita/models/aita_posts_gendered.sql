WITH data AS (
  SELECT *
    , ARRAY_LENGTH(REGEXP_EXTRACT_ALL(CONCAT(selftext, title), r'(?i)\bhe\b')) hes
    , ARRAY_LENGTH(REGEXP_EXTRACT_ALL(CONCAT(selftext, title), r'(?i)\bshe\b')) shes
    , ARRAY_LENGTH(REGEXP_EXTRACT_ALL(CONCAT(selftext, title), r'(?i)\bher\b')) hers
    , ARRAY_LENGTH(REGEXP_EXTRACT_ALL(CONCAT(selftext, title), r'(?i)\bhis\b')) hiss
    , ARRAY_LENGTH(REGEXP_EXTRACT_ALL(CONCAT(selftext, title), r'(?i)\bthey\b')) theys
    , ARRAY_LENGTH(REGEXP_EXTRACT_ALL(CONCAT(selftext, title), r'(?i)\bgirlfriend\b')) gfs
    , ARRAY_LENGTH(REGEXP_EXTRACT_ALL(CONCAT(selftext, title), r'(?i)\bboyfriend\b')) bfs
  FROM {{ref('aita_posts')}}
  WHERE link_flair_text IS NOT NULL
), gendered_data AS (
  SELECT *
    , CASE
      WHEN males > 2+females*2 THEN 'to_male'
      WHEN females > 2+males*2 THEN 'to_female'
      ELSE 'neutral'
      END to_gender
  FROM (
    SELECT *, hes+shes+hers+hiss+theys+gfs+bfs totalgender, hes+hiss+bfs males, shes+hers+gfs females
    FROM data
  )
)


SELECT CASE link_flair_text
    WHEN 'not the a-hole' THEN 'no asshole'
    WHEN 'no a-holes here' THEN 'no asshole'
    WHEN 'everyone sucks' THEN 'asshole'
    WHEN 'asshole' THEN 'asshole'
  END judgement
  , *
FROM gendered_data
WHERE link_flair_text IS NOT NULL
