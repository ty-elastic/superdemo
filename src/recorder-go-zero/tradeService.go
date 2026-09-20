package main

import (
	"context"
	"fmt"
	"os"

	log "github.com/sirupsen/logrus"

	"database/sql"

	_ "github.com/lib/pq"
)

type TradeService struct {
	db *sql.DB
}

func NewTradeService() (*TradeService, error) {
	c := TradeService{}

	psqlInfo := fmt.Sprintf("host=%s port=%d user=%s "+
		"password=%s dbname=%s sslmode=%s",
		os.Getenv("POSTGRESQL_HOST"), 5432, os.Getenv("POSTGRESQL_USER"), os.Getenv("POSTGRESQL_PASSWORD"), os.Getenv("POSTGRESQL_DBNAME"), "disable")
	db, err := sql.Open("postgres", psqlInfo)
	if err != nil {
		log.Fatal("unable to connect to database: ", err)
		os.Exit(1)
	}
	c.db = db

	err = c.db.Ping()
	if err != nil {
		log.Fatal("unable to connect to database: ", err)
		os.Exit(1)
	}

	return &c, nil
}

func (c *TradeService) RecordTrade(context context.Context, trade *Trade) (*Trade, error) {

	sqlStatement := `
		INSERT INTO trades (trade_id, customer_id, symbol, action, shares, share_price)
		VALUES ($1, $2, $3, $4, $5, $6)
	`

	// insert trade
	_, err := c.db.ExecContext(context, sqlStatement, trade.TradeId, trade.CustomerId, trade.Symbol, trade.Action, trade.Shares, trade.SharePrice)
	if err != nil {
		return nil, err
	}

	logger.WithContext(context).Info("trade committed for " + trade.CustomerId)

	return trade, nil
}
