package main

import (
	"context"
	"fmt"
	"os"
	"strconv"

	log "github.com/sirupsen/logrus"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
	"go.opentelemetry.io/otel/trace"

	"database/sql"

	_ "github.com/go-sql-driver/mysql"

	"github.com/XSAM/otelsql"
	semconv "go.opentelemetry.io/otel/semconv/v1.37.0"
)

type TradeService struct {
	db                 *sql.DB
	transactionCounter metric.Int64Counter
}

func NewTradeService() (*TradeService, error) {
	c := TradeService{}

	// [scheme://][user[:password]@][protocol([addr])]/dbname[?param1=value1&paramN=valueN]
	// spring.datasource.url=jdbc:${DB_PROTOCOL}://${POSTGRESQL_HOST}:${DB_PORT}${DB_OPTIONS}

	//connString := fmt.Sprintf("%s://%s:%s@%s:%s/trades?Trusted_Connection=false&Encrypt=false&TrustServerCertificate=true", os.Getenv("MYSQL_PROTOCOL"), os.Getenv("MYSQL_USER"), os.Getenv("MYSQL_PASSWORD"), os.Getenv("MYSQL_HOST"), os.Getenv("MYSQL_PORT"))
	connString := fmt.Sprintf("%s:%s@tcp(%s:%s)/main?tls=false&interpolateParams=true", os.Getenv("MYSQL_USER"), os.Getenv("MYSQL_PASSWORD"), os.Getenv("MYSQL_HOST"), os.Getenv("MYSQL_PORT"))
	logger.Warn(connString)

	port, err := strconv.ParseInt(os.Getenv("MYSQL_PORT"), 10, 64)

	db, err := otelsql.Open("mysql", connString, otelsql.WithSQLCommenter(true), otelsql.WithAttributes(
		semconv.DBSystemNameMySQL,
		semconv.ServerAddress(os.Getenv("MYSQL_HOST")),
		semconv.ServerPortKey.Int64(port),
		attribute.String("db.system", "mysql"),
		attribute.String("span.destination.service.resource", os.Getenv("MYSQL_HOST")),
		attribute.String("span.subtype", "mysql"),
		attribute.String("service.target.name", os.Getenv("MYSQL_HOST")),
	))

	if err != nil {
		log.Fatal("unable to connect to database: ", err)
		os.Exit(1)
	}
	c.db = db

	// Register DB stats to meter
	err = otelsql.RegisterDBStatsMetrics(db, otelsql.WithAttributes(
		semconv.DBSystemNameMySQL,
		semconv.ServerAddress(os.Getenv("MYSQL_HOST")),
		semconv.ServerPortKey.Int64(port),
	))
	if err != nil {
		log.Fatal("unable to setup dbstats: ", err)
		os.Exit(1)
	}

	err = c.db.Ping()
	if err != nil {
		log.Fatal("unable to connect to database: ", err)
		os.Exit(1)
	}

	meter := otel.Meter("tradeService")
	transactionCounter, err := meter.Int64Counter(
		"sql_transaction.counter",
		metric.WithDescription("Number of SQL transactions"),
		metric.WithUnit("{transaction}"),
	)
	c.transactionCounter = transactionCounter

	return &c, nil
}

func (c *TradeService) RecordTrade(context context.Context, trade *Trade) (*Trade, error) {
	sqlStatement := `
		INSERT INTO trades (trade_id, customer_id, symbol, action, shares, share_price)
		VALUES (?, ?, ?, ?, ?, ?)
	`

	// insert trade
	res, err := c.db.ExecContext(context, sqlStatement, trade.TradeId, trade.CustomerId, trade.Symbol, trade.Action, trade.Shares, trade.SharePrice)
	if err != nil {
		logger.Warn(err)
		span := trace.SpanFromContext(context)
		span.RecordError(err, trace.WithStackTrace(true))
		return nil, err
	}

	c.transactionCounter.Add(context, 1)

	insertId, _ := res.LastInsertId()
	trace.SpanFromContext(context).SetAttributes(attribute.Int64("sql_insert_id", insertId))

	//logger.WithContext(context).Info("trade committed for " + trade.CustomerId)
	logger.WithContext(context).Infof("recorded transaction for %s: %s %d shares of %s @ %f", trade.CustomerId, trade.Action, trade.Shares, trade.Symbol, trade.SharePrice)

	return trade, nil
}
