UPDATE blocks SET consensus = FALSE, updated_at = NOW()
WHERE consensus AND number IN (
  SELECT b0.number - 1 FROM "blocks" AS b0
  LEFT JOIN "blocks" AS b1 ON (b0."parent_hash" = b1."hash") AND b1."consensus"
  WHERE b0."number" > 0 AND b0."consensus" AND b1."hash" IS NULL
);
