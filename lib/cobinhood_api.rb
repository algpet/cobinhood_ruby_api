require 'net/http'
require 'json'
require 'logger'

LIVE_API = "https://api.cobinhood.com"

# API resources. SYSTEM
SYSTEM_INFO = "/v1/system/info"
SYSTEM_TIME = "/v1/system/time"

# API resources. MARKET
MARKET_CURRENCIES = "/v1/market/currencies"
MARKET_TRADING_PAIRS = "/v1/market/trading_pairs"
MARKET_ORDER_BOOK = "/v1/market/orderbooks/%{trading_pair}?limit=%{limit}"
MARKET_STATS = "/v1/market/stats"
MARKET_TICKER = "/v1/market/tickers/%{trading_pair}"
MARKET_RECENT_TRADES = "/v1/market/trades/%{trading_pair}"

# API resources. CANDLES
CHART_CANDLES = '/v1/chart/candles/%{trading_pair}?timeframe=%{timeframe}'
class CHART_CANDLE_TIMEFRAMES
    TIMEFRAME_1_MINUTE = "1m"
    TIMEFRAME_5_MINUTES = "5m"
    TIMEFRAME_15_MINUTES = "15m"
    TIMEFRAME_30_MINUTES = "30m"
    TIMEFRAME_1_HOUR = "1h"
    TIMEFRAME_3_HOURS = "3h"
    TIMEFRAME_6_HOURS = "6h"
    TIMEFRAME_12_HOURS = "12h"
    TIMEFRAME_1_DAY = "1D"
    TIMEFRAME_7_DAYS = "7D"
    TIMEFRAME_14_DAYS = "14D"
    TIMEFRAME_1_MONTH = "1M"
end

# API resources. TRADING
TRADING_ORDERS = '/v1/trading/orders'
TRADING_ORDER = '/v1/trading/orders/%{order_id}'
TRADING_ORDERS_HISTORY = '/v1/trading/order_history'
TRADING_TRADE = '/v1/trading/trades/%{trade_id}'
TRADING_TRADE_HISTORY = '/v1/trading/trades'
TRADING_ORDER_TRADES = '/v1/trading/orders/%{order_id}/trades'

class TRADING_ORDER_SIDE
    SIDE_BUY = "bid"
    SIDE_SELL = "ask"
    SIDE_BID = "bid"
    SIDE_ASK = "ask"
end

class TRADING_ORDER_TYPE
    TYPE_MARKET = "market"
    TYPE_LIMIT  = "limit"
    TYPE_STOP   = "stop"
    TYPE_STOP_LIMIT = "stop_limit"
end

# API resources. WALLET
WALLET_DEPOSIT_ADDRESSES = "/v1/wallet/deposit_addresses"
WALLET_WITHDRAWAL_ADDRESSES = "/v1/wallet/withdrawal_addresses"
WALLET_LEDGER = "/v1/wallet/ledger"
WALLET_DEPOSIT = "/v1/wallet/deposits/%{deposit_id}"
WALLET_WITHDRAWAL = "/v1/wallet/withdrawals/%{withdrawal_id}"
WALLET_WITHDRAWALS = "/v1/wallet/withdrawals"
WALLET_DEPOSITS = "/v1/wallet/deposits"

class CobinhoodApi
    VERB_MAP = {
        :get    => Net::HTTP::Get,
        :post   => Net::HTTP::Post,
        :put    => Net::HTTP::Put,
        :delete => Net::HTTP::Delete
    }

    def initialize(api_key:nil,console_log:false,logfile:"cobinhood.log")
        unless api_key.nil?
            @auth = {:authorization => api_key}
            @live_api = URI(LIVE_API)
            @http =  Net::HTTP.new(@live_api.host,@live_api.port)
            @http.use_ssl = true
            #@http.set_debug_output($stdout)
        else
            @auth = nil
            @live_api = nil
            @http = nil
        end

        @loggers = []
        if console_log
            @loggers.push(Logger.new(STDOUT))
        end
        unless logfile.nil?
            @loggers.push(Logger.new(logfile))
        end
    end

    def log(message)
        @loggers.each do |logger|
            logger.info(message)
        end
    end

    """
    core stuff for later use
    """
    def request(method,request_url,params:nil,data:nil,auth:false)
        unless params.nil?
            request_url = request_url % params
        end
        uri = URI(LIVE_API + request_url)
        log(method.to_s + " " + uri.to_s + " data=" + data.to_s)

        if auth
            request = VERB_MAP[method].new(uri.request_uri)
            request[:authorization] = @auth[:authorization]
            unless method.equal? :get
                request[:nonce] = Time.now.to_i.to_s
            end
            unless data.nil?
                request.body = JSON.generate(data)
            end
            response = @http.request(request).body
        else
            response = Net::HTTP.get(uri)
        end
        JSON.parse(response)

    end

    def get(request_url,params:nil,auth:nil)
        request(:get,request_url,params:params,auth:auth)
    end

    def get_auth(request_url,params:nil)
        request(:get,request_url,params:params,auth:true)
    end

    def put(request_url,params:nil,data:nil)
        request(:put,request_url,params:params,data:data,auth:true)
    end

    def post(request_url,params:nil,data:nil)
        request(:post,request_url,params:params,data:data,auth:true)
    end

    def delete(request_url,params:nil)
        request(:delete,request_url,params:params,auth:true)
    end

    """
    extract contents of API responce. Only cream go outside
    """
    def result(request_result,entry=nil)
        return nil if request_result.nil?
        return nil unless request_result.key?("success") and request_result.key?("result")
        return request_result unless request_result["success"]

        if entry.nil?
            request_result["result"]
        else
            request_result["result"][entry]
        end
    end

    def outcome(request_result)
        return nil if request_result.nil?
        return nil unless request_result.key?("success") and request_result.key?("result")
        request_result['success']
    end


    """
    more routines
    """
    def add_filter(filter,value,url,params)
        unless value.nil?
            if url["?"]
                url += "&"
            else
                url += "?"
            end
            url += filter + "=%{" + filter + "}"
            params[filter.to_sym] = value
        end
        url
    end


    def get_system_info
        result get(SYSTEM_INFO) ,"info"
    end

    def get_system_time
        result get(SYSTEM_TIME)
    end

    def get_market_currencies
        result get(MARKET_CURRENCIES),"currencies"
    end

    def get_market_trading_pairs
        result get(MARKET_TRADING_PAIRS),"trading_pairs"
    end

    def get_market_order_book(trading_pair,limit=50)
        raw_order_book = result get(MARKET_ORDER_BOOK,params:{:trading_pair=>trading_pair,:limit=>limit}),"orderbook"
        order_book = {asks:[],bids:[]}
        %w(asks bids).each do |side|
            raw_order_book[side].each do |offer|
                order_book[side.to_sym].push({"price" => offer[0].to_f, "size" => offer[2].to_f,"count" => offer[1].to_i})
            end
        end
        order_book
    end

    def get_market_stats
        result get(MARKET_STATS)
    end

    def get_all_last_prices
        stats = result get(MARKET_STATS)
        unless stats.nil?
            prices = {}
            stats.each do |pair,stat|
                prices[pair] = stat["last_price"].to_f
            end
            prices
        end
    end

    def get_ticker(trading_pair)
        result get(MARKET_TICKER, params:{:trading_pair=>trading_pair}) , "ticker"
    end

    def get_recent_trades(trading_pair)
        result get(MARKET_RECENT_TRADES, params:{:trading_pair=>trading_pair}),"trades"
    end

    """
    CHART resource methods
    """
    def get_chart_candles(trading_pair,timeframe=CHART_CANDLE_TIMEFRAMES::TIMEFRAME_1_HOUR,start_time=nil,end_time=nil)
        params = {:trading_pair => trading_pair,:timeframe => timeframe}
        base_url = CHART_CANDLES
        base_url = add_filter("start_time",start_time,base_url,params)
        base_url = add_filter("end_time", end_time, base_url, params)
        result get(base_url,params:params) ,"candles"
    end

    """
    TRADING resource methods
    """
    def get_orders(trading_pair=nil)
        params ={}
        base_url = add_filter("trading_pair_id",trading_pair,TRADING_ORDERS,params)
        result get_auth(base_url,params:params) , "orders"
    end

    def get_order_history(trading_pair=nil)
        params ={}
        base_url = add_filter("trading_pair_id",trading_pair,TRADING_ORDERS_HISTORY,params)
        result get_auth(base_url,params:params) , "orders"
    end

    def get_order(order_id)
        params = {:order_id => order_id}
        result get_auth(TRADING_ORDER, params:params),"order"
    end

    def get_order_trades(order_id)
        params = {:order_id => order_id}
        result get_auth(TRADING_ORDER_TRADES, params:params),"trades"
    end

    def get_trade(trade_id)
        params = {:trade_id => trade_id}
        result get_auth(TRADING_TRADE, params:params) , "trade"
    end

    def get_trade_history(trading_pair=nil)
        params ={}
        base_url = add_filter("trading_pair_id",trading_pair,TRADING_TRADE_HISTORY,params)
        result get_auth(base_url, params:params),"trades"
    end

    def place_order(trading_pair,side,order_type,size,price=nil)
        unless order_type == TRADING_ORDER_TYPE::TYPE_MARKET
            return nil if price.nil?
        end
        data = {
            :trading_pair_id => trading_pair,
            :side => side,
            :type => order_type,
            :size => size.to_s,
            :price => price.to_s
        }
        result post(TRADING_ORDERS,data:data) , "order"
    end

    def modify_order(order_id,size,price)
        params = {:order_id => order_id}
        data = {
            :size => size.to_s,
            :price => price.to_s
        }
        outcome put(TRADING_ORDER,params:params,data:data)
    end

    def cancel_order(order_id)
        params = {:order_id => order_id}
        outcome delete(TRADING_ORDER, params:params)
    end

    """
    WALLET resource methods
    """
    def get_ledger(currency=nil)
        params = {}
        base_url = add_filter("currency", currency, WALLET_LEDGER, params)
        result get_auth(base_url, params:params) ,"ledger"
    end

    def get_deposit_addresses(currency=nil)
        params = {}
        base_url = add_filter("currency",currency, WALLET_DEPOSIT_ADDRESSES, params)
        result get_auth(base_url, params:params),"deposit_addresses"
    end

    def get_withdrawal_addresses(currency=nil)
        params = {}
        base_url = add_filter("currency", currency, WALLET_WITHDRAWAL_ADDRESSES, params)
        result get_auth(base_url, params:params),"withdrawal_addresses"
    end

    def get_deposit_history(currency=nil)
        params = {}
        base_url = add_filter("currency", currency, WALLET_DEPOSITS, params)
        result get_auth(base_url, params:params),"deposits"
    end

    def get_withdrawal_history(currency=nil)
        params = {}
        base_url = add_filter("currency", currency, WALLET_WITHDRAWALS, params)
        result get_auth(base_url, params:params),"withdrawals"
    end

    def get_withdrawal(withdrawal_id)
        params = {:withdrawal_id =>withdrawal_id}
        result get_auth(WALLET_WITHDRAWAL, params:params),"withdrawal"
    end

    def get_deposit(deposit_id)
        params = {:deposit_id => deposit_id}
        result get_auth(WALLET_DEPOSIT, params:params),"deposit"
    end
end
