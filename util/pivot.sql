CREATE OR REPLACE FUNCTION
`fhoffa.x.normalize_col_name`(col_name STRING) AS (
  REGEXP_REPLACE(col_name,r'[/+#|]', '_')
);

CREATE OR REPLACE PROCEDURE `fhoffa.x.pivot`(
  table_name STRING
  , destination_table STRING
  , row_ids ARRAY<STRING>
  , pivot_col_name STRING
  , pivot_col_value STRING
  , max_columns INT64
  , aggregation STRING
  , optional_limit STRING
  )
BEGIN
  DECLARE pivotter STRING;

  EXECUTE IMMEDIATE (
    "SELECT STRING_AGG(' "||aggregation
    ||"""(IF('||@pivot_col_name||'="'||x.value||'", '||@pivot_col_value||', null)) e_'||`fhoffa.x.normalize_col_name`(x.value))
   FROM UNNEST((
       SELECT APPROX_TOP_COUNT("""||pivot_col_name||", @max_columns) FROM `"||table_name||"`)) x"
  ) INTO pivotter
  USING pivot_col_name AS pivot_col_name, pivot_col_value AS pivot_col_value, max_columns AS max_columns;

  EXECUTE IMMEDIATE (
   'CREATE OR REPLACE TABLE `'||destination_table
   ||'` AS SELECT '
   ||(SELECT STRING_AGG(x) FROM UNNEST(row_ids) x)
   ||', '||pivotter
   ||' FROM `'||table_name||'` GROUP BY '
   || (SELECT STRING_AGG(''||(i+1)) FROM UNNEST(row_ids) WITH OFFSET i)||' ORDER BY '
   || (SELECT STRING_AGG(''||(i+1)) FROM UNNEST(row_ids) WITH OFFSET i)
   ||' '||optional_limit
  );
END;
