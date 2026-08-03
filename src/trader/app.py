from flask import Flask, request
import logging

import random
import os
import uuid
import math
import hashlib

import requests
from werkzeug.middleware.proxy_fix import ProxyFix

from opentelemetry import trace, baggage, context
from opentelemetry.exporter.otlp.proto.http.metric_exporter import OTLPMetricExporter
from opentelemetry.sdk.metrics.export import (
    PeriodicExportingMetricReader,
)
from opentelemetry.sdk.metrics import (
    MeterProvider,
)

from opentelemetry import _logs as logs
from opentelemetry.processor.baggage import BaggageSpanProcessor, BaggageLogProcessor, ALLOW_ALL_BAGGAGE_KEYS

ATTRIBUTE_PREFIX = "com.example"
TRADE_TIMEOUT = 5

app = Flask(__name__)
app.logger.setLevel(logging.INFO)

 # Apply ProxyFix to correctly handle X-Forwarded-For
# x_for=1 indicates that one proxy is setting the X-Forwarded-For header
# Adjust x_for based on the number of proxies in front of your Flask app
app.wsgi_app = ProxyFix(app.wsgi_app, x_for=2)

import model

def init_otel(): 
    try:
        trace.get_tracer_provider().add_span_processor(BaggageSpanProcessor(ALLOW_ALL_BAGGAGE_KEYS))
    except:
        pass

    if 'OTEL_PYTHON_LOGGING_AUTO_INSTRUMENTATION_ENABLED' in os.environ:
        print("enable otel logging")
        logs.get_logger_provider().add_log_record_processor(BaggageLogProcessor(ALLOW_ALL_BAGGAGE_KEYS))     
        root_logger = logging.getLogger()
        for handler in root_logger.handlers:
            if isinstance(handler, logging.StreamHandler):
                root_logger.removeHandler(handler)

    tracer = trace.get_tracer(__name__)

    metrics_provider = MeterProvider(metric_readers=[PeriodicExportingMetricReader(OTLPMetricExporter(), export_interval_millis=5000)])  # Export every 5 seconds
    meter = metrics_provider.get_meter("trader")

    trading_revenue_counter = meter.create_counter("trading_revenue", "dollars")
    shares_traded_per_customer_gauge = meter.create_gauge("shares_traded_per_customer", unit='shares', description='shares_traded_per_customer')
    share_price_gauge = meter.create_gauge("share_price", unit='dollars', description='share_price')

    shares_traded_per_customer_histogram = meter.create_histogram(
        name="shares_traded_per_customer_histogram", unit='shares', description='shares_traded_per_customer')

    app.logger.info('metrics created')
    return tracer, trading_revenue_counter, shares_traded_per_customer_gauge, share_price_gauge, shares_traded_per_customer_histogram

tracer, trading_revenue_counter, shares_traded_per_customer_gauge, share_price_gauge, shares_traded_per_customer_histogram = init_otel()

def set_attribute_and_baggage(key, value):
    # always set it on the current span
    trace.get_current_span().set_attribute(key, value)
    # and attach it to baggage
    context.attach(baggage.set_baggage(key, value))

def conform_request_bool(value):
    return value.lower() == 'true'

@app.route('/health')
def health():
    return f"KERNEL OK"

@app.post('/reset')
def reset():
    model.reset_market_data()
    return None
    
def decode_common_args():
    params = request.get_json()

    trade_id = str(uuid.uuid4())

    customer_id = params.get('customer_id', None)
    if customer_id is None:
        raise Exception("malformed customer_id", request.remote_addr)
    set_attribute_and_baggage(f"{ATTRIBUTE_PREFIX}.customer_id", customer_id)

    subscription = params.get('subscription', None)
    if subscription is not None:
        set_attribute_and_baggage(f"{ATTRIBUTE_PREFIX}.subscription", subscription)

    day_of_week = params.get('day_of_week', None)
    if day_of_week is None:
        day_of_week = random.choice(['M', 'Tu', 'W', 'Th', 'F'])
    set_attribute_and_baggage(f"{ATTRIBUTE_PREFIX}.day_of_week", day_of_week)
 
    symbol = params.get('symbol', "OELK")
    set_attribute_and_baggage(f"{ATTRIBUTE_PREFIX}.symbol", symbol)

    data_source = params.get('data_source', 'monkey')
    set_attribute_and_baggage(f"{ATTRIBUTE_PREFIX}.data_source", data_source)

    classification = params.get('classification', None)
    if classification is not None:
        set_attribute_and_baggage(f"{ATTRIBUTE_PREFIX}.classification", classification)

    flags = params.get('flags', None)
    # if flags is not None:
    #     set_attribute_and_baggage(f"{ATTRIBUTE_PREFIX}.flags", flags)

    # forced errors
    latency_amount = params.get('latency_amount', 0)
    latency_action = params.get('latency_action', None)
    error_model = params.get('error_model', False)
    error_db = params.get('error_db', False)
    error_db_service = params.get('error_db_service', None)
    
    skew_market_factor = params.get('skew_market_factor', 0)

    return trade_id, customer_id, day_of_week, symbol, latency_amount, latency_action, error_model, error_db, error_db_service, skew_market_factor, data_source, classification, flags

@tracer.start_as_current_span("trade")
def trade(*, trade_id, customer_id, symbol, day_of_week, shares, share_price, action, error_db, data_source, classification, error_db_service=None, flags):

    app.logger.info(f"trade requested for {symbol} on day {day_of_week}")

    trace.get_current_span().set_attribute(f"{ATTRIBUTE_PREFIX}.action", action)
    trace.get_current_span().set_attribute(f"{ATTRIBUTE_PREFIX}.shares", shares)
    trace.get_current_span().set_attribute(f"{ATTRIBUTE_PREFIX}.share_price", share_price)
    if action == 'buy' or action == 'sell':
        trace.get_current_span().set_attribute(f"{ATTRIBUTE_PREFIX}.value", shares * share_price)
        trading_revenue_counter.add(math.ceil(share_price * shares * .001))
    else:
        trace.get_current_span().set_attribute(f"{ATTRIBUTE_PREFIX}.value", 0)

    attributes = {
        "customer_id": customer_id,
        "symbol": symbol
    }
    # just for show, since you would randomly get the last value set
    shares_traded_per_customer_gauge.set(shares, attributes)
    # the real value
    shares_traded_per_customer_histogram.record(shares, attributes)

    attributes = {
        "symbol": symbol
    }
    share_price_gauge.set(share_price, attributes)

    if flags is not None and "HASHNEWALG" in flags:
        app.logger.info(f"hashing with scrypt")
        hashed_customer_id = hashlib.scrypt(customer_id.encode('utf-8'), salt=os.urandom(16), n=2**14, r=8, p=1, dklen=64)
        obfuscated_customer_id = hashed_customer_id.hex()
    else:
        app.logger.info(f"hashing with sha256")
        hashed_customer_id = hashlib.sha256(customer_id.encode('utf-8'))
        obfuscated_customer_id = hashed_customer_id.hexdigest()

    response = {}
    response['id'] = trade_id
    response['symbol']= symbol
    
    params={'customer_id': obfuscated_customer_id, 'trade_id': trade_id, 'symbol': symbol, 'shares': shares, 'share_price': share_price, 'action': action}
    #print(params)
    if error_db is True:
        params['share_price'] = -share_price
        params['shares'] = -shares
        if error_db_service is not None:
            params['service'] = error_db_service
    if flags is not None:
        params['flags'] = flags
        
    trade_response = requests.post(os.environ['ROUTER_ENDPOINT'], params=params, timeout=TRADE_TIMEOUT)
    trade_response.raise_for_status()

    response['shares']= shares
    response['share_price']= share_price
    response['action']= action
    
    app.logger.info(f"traded {symbol} on day {day_of_week} for {obfuscated_customer_id}, email:{customer_id}@email.co")
    
    return response
    
@app.post('/trade/force')
def trade_force():
    trade_id, customer_id, day_of_week, symbol, latency_amount, latency_action, error_model, error_db, error_db_service, skew_market_factor, data_source, classification, flags = decode_common_args()

    params = request.get_json()
    action = params.get('action')
    shares = params.get('shares')
    share_price = params.get('share_price')

    return trade (data_source=data_source, classification=classification, trade_id=trade_id, symbol=symbol, customer_id=customer_id, day_of_week=day_of_week, shares=shares, share_price=share_price, action=action, error_db=False, flags=flags)

@app.post('/trade/request')
def trade_request():
    trade_id, customer_id, day_of_week, symbol, latency_amount, latency_action, error_model, error_db, error_db_service, skew_market_factor, data_source, classification, flags = decode_common_args()
    
    action, shares, share_price = run_model(trade_id=trade_id, customer_id=customer_id, day_of_week=day_of_week, symbol=symbol, 
                                                   error=error_model, latency_amount=latency_amount, latency_action=latency_action, skew_market_factor=skew_market_factor)
    
    return trade (data_source=data_source, classification=classification, trade_id=trade_id, symbol=symbol, customer_id=customer_id, day_of_week=day_of_week, shares=shares, share_price=share_price, action=action, error_db=error_db, error_db_service=error_db_service, flags=flags)

@tracer.start_as_current_span("run_model")
def run_model(*, trade_id, customer_id, day_of_week, symbol, error=False, latency_amount=0.0, latency_action=None, skew_market_factor=0):

    market_factor, share_price = model.sim_market_data(symbol=symbol, day_of_week=day_of_week, skew_market_factor=skew_market_factor)
    trace.get_current_span().set_attribute(f"{ATTRIBUTE_PREFIX}.market_factor", market_factor)

    action, shares = model.sim_decide(error=error, latency_amount=latency_amount, latency_action=latency_action, symbol=symbol, market_factor=market_factor)

    return action, shares, share_price