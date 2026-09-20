package main

import (
	"encoding/json"
	"net/http"
	"strconv"
)

type TradeController struct {
	mux          *http.ServeMux
	tradeService *TradeService
}

func NewTradeController(tradeService *TradeService) (*TradeController, error) {
	c := TradeController{tradeService: tradeService}
	c.mux = http.NewServeMux()

	c.mux.HandleFunc("/record", c.record)
	c.mux.HandleFunc("/health", c.health)

	return &c, nil
}

type ResponseData struct {
	Message string `json:"message"`
}

func (c *TradeController) health(w http.ResponseWriter, req *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	data := ResponseData{
		Message: "KERNEL OK",
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(data)
}

func (c *TradeController) record(w http.ResponseWriter, req *http.Request) {
	ctx := req.Context()
	query := req.URL.Query()

	customerId := query.Get("customer_id")
	tradeId := query.Get("trade_id")
	symbol := query.Get("symbol")
	shares, _ := strconv.ParseInt(query.Get("shares"), 10, 32)
	sharePrice, _ := strconv.ParseFloat(query.Get("share_price"), 32)
	action := query.Get("action")

	trade := Trade{CustomerId: customerId, TradeId: tradeId, Symbol: symbol, Shares: shares, SharePrice: sharePrice, Action: action}

	res, err := c.tradeService.RecordTrade(ctx, &trade)

	notify(ctx, &trade)

	w.Header().Set("Content-Type", "application/json")
	if err != nil {
		data := ResponseData{
			Message: err.Error(),
		}
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(data)
	} else {
		data := ResponseData{
			Message: res.Action,
		}
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(data)
	}
}

func (c *TradeController) Run() error {

	err := http.ListenAndServe("0.0.0.0:9003", c.mux)
	if err != nil {
		return err
	}

	return nil
}
