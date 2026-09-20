package com.example.recorder;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import org.springframework.stereotype.Service;

/**
 * Service layer is where all the business logic lies
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class TradeService {
	private final TradeNotifier tradeNotifier;
	private final TradeRecorder tradeRecorder;

    public Trade processTrade (Trade trade, String flags){
        Trade resp = tradeRecorder.recordTrade(trade);

        tradeNotifier.notify(trade, flags);

        return resp;
    }
}
