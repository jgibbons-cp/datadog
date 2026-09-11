#!/bin/bash
# Creates the Datadog DBM user, grants, and the explain_statement procedures.
set -euo pipefail

mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" <<EOSQL
CREATE USER IF NOT EXISTS 'datadog'@'%' IDENTIFIED BY '${MYSQL_DD_PASSWORD}';
ALTER USER 'datadog'@'%' WITH MAX_USER_CONNECTIONS 10;

GRANT REPLICATION CLIENT ON *.* TO 'datadog'@'%';
GRANT PROCESS              ON *.* TO 'datadog'@'%';
GRANT SELECT               ON performance_schema.* TO 'datadog'@'%';
GRANT UPDATE               ON performance_schema.setup_consumers TO 'datadog'@'%';
GRANT UPDATE               ON performance_schema.setup_instruments TO 'datadog'@'%';
GRANT SELECT               ON mysql.* TO 'datadog'@'%';
GRANT SELECT               ON __DEMO_NAME___orders.* TO 'datadog'@'%';

CREATE SCHEMA IF NOT EXISTS datadog;
GRANT EXECUTE ON datadog.* TO 'datadog'@'%';
GRANT CREATE TEMPORARY TABLES ON datadog.* TO 'datadog'@'%';

DROP PROCEDURE IF EXISTS datadog.explain_statement;
DROP PROCEDURE IF EXISTS datadog.enable_events_statements_consumers;
DROP PROCEDURE IF EXISTS __DEMO_NAME___orders.explain_statement;

DELIMITER \$\$
CREATE PROCEDURE datadog.explain_statement(IN query TEXT)
    SQL SECURITY DEFINER
BEGIN
    SET @explain := CONCAT('EXPLAIN FORMAT=json ', query);
    PREPARE stmt FROM @explain;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END \$\$

CREATE PROCEDURE __DEMO_NAME___orders.explain_statement(IN query TEXT)
    SQL SECURITY DEFINER
BEGIN
    SET @explain := CONCAT('EXPLAIN FORMAT=json ', query);
    PREPARE stmt FROM @explain;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END \$\$

CREATE PROCEDURE datadog.enable_events_statements_consumers()
    SQL SECURITY DEFINER
BEGIN
    UPDATE performance_schema.setup_consumers
       SET enabled = 'YES' WHERE name LIKE 'events_statements_%';
    UPDATE performance_schema.setup_consumers
       SET enabled = 'YES' WHERE name = 'events_waits_current';
END \$\$
DELIMITER ;

GRANT EXECUTE ON PROCEDURE datadog.enable_events_statements_consumers TO 'datadog'@'%';

GRANT EXECUTE ON PROCEDURE __DEMO_NAME___orders.explain_statement TO 'datadog'@'%';
FLUSH PRIVILEGES;
EOSQL

echo "[init] Datadog DBM user configured for MySQL."
