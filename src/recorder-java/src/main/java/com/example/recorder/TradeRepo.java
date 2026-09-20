package com.example.recorder;

import org.springframework.data.jpa.repository.JpaRepository;

/**
 * Repository is an interface that provides access to data in a database
 */
public interface TradeRepo extends JpaRepository<Trade, String> {
}