package com.example.recorder;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Column;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@NoArgsConstructor
@AllArgsConstructor
@Data
@Entity
@Table(name = "trades")
public class Trade {
  @Id
  @Column(name="trade_id")
  public String tradeId;

  @Column(name="customer_id")
  public String customerId;
  @Column(name="symbol")
  public String symbol;

  @Column(name="shares")
  public int shares;

  @Column(name="share_price")
  public float sharePrice;

  @Column(name="action")
  public String action;
}