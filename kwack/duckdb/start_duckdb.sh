#!/bin/bash

# 🦆 Start DuckDB with flights.parquet loaded
echo "🦆 Starting DuckDB with flights.parquet..."
echo "📊 Available commands:"
echo "   SELECT * FROM 'flights.parquet' LIMIT 10;"
echo "   DESCRIBE SELECT * FROM 'flights.parquet';"
echo "   SELECT COUNT(*) FROM 'flights.parquet';"
echo "   .quit to exit"
echo ""

# Start DuckDB and automatically create a view for the parquet file
duckdb -c "
CREATE VIEW flights AS SELECT * FROM 'flights.parquet';
SELECT 'DuckDB ready! Use: SELECT * FROM flights LIMIT 10;' AS message;
" && duckdb -ui