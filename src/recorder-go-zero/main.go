package main

import (
	"os"

	log "github.com/sirupsen/logrus"
)

var (
	logger *log.Logger
)

func initLogrus() {
	logger = log.New()

	logger.SetFormatter(&log.JSONFormatter{FieldMap: log.FieldMap{
		"msg":  "message",
		"time": "timestamp",
	}})

	logger.SetOutput(os.Stdout)
	logger.SetLevel(log.InfoLevel)
}

func main() {

	initLogrus()

	tradeService, _ := NewTradeService()
	tradeController, _ := NewTradeController(tradeService)

	err := tradeController.Run()
	if err != nil {
		logger.Warn(err)
	}
}
