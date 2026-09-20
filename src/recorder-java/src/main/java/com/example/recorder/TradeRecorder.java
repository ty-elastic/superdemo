package com.example.recorder;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import com.example.recorder.Utilities;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.*;

/**
 * Service layer is where all the business logic lies
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class TradeRecorder {
    
    private final Utilities utilities;
    private final TradeRepo tradeRepo;

    @Transactional
    public Trade recordTrade (Trade trade){
        Trade savedTrade = tradeRepo.save(trade);

        return savedTrade;
    }
}
