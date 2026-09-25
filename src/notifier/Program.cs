using Npgsql;
using Microsoft.AspNetCore.Mvc;
using System;
using System.Globalization;
using System.Diagnostics;
using System.Diagnostics.Metrics;

string ConnectionString() {
    string postgresql_host = Environment.GetEnvironmentVariable("POSTGRESQL_HOST");
    string postgresql_port = Environment.GetEnvironmentVariable("POSTGRESQL_PORT");
    string postgresql_dbname = Environment.GetEnvironmentVariable("POSTGRESQL_DBNAME");
    string postgresql_user = Environment.GetEnvironmentVariable("POSTGRESQL_USER");
    string postgresql_password = Environment.GetEnvironmentVariable("POSTGRESQL_PASSWORD");

    var connString = "Host=" + postgresql_host + ":" + postgresql_port + ";";
    connString += "Username=" + postgresql_user + ";Password=" + postgresql_password + ";";
    connString += "Database=" + postgresql_dbname + ";";
    connString += "Maximum Pool Size=25;Timeout=1;Pooling=True;";

    //app.Logger.LogInformation("connString=" + connString);

    return connString;
}

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddNpgsqlDataSource(ConnectionString());
builder.Services.AddLogging();

var app = builder.Build();

const string AttributePrefix = "com.example";
const string ServiceName = "notifier";
var activitySource = new ActivitySource(ServiceName);
var meter = new Meter(ServiceName);
var requestCounter = meter.CreateCounter<long>("requests", "count");

string HealthHandler(ILogger<Program> logger)
{
    return "KERNEL OK";
}

Random rnd = new Random();

void QueryPostgresql(string trade_id, string flags, NpgsqlDataSource ds, ILogger<Program> logger)
{
    using (var activity = activitySource.StartActivity("QueryPostgresql")) {

        var sqlQuery = "SELECT trade_id, customer_id, symbol, share_price FROM trades WHERE trade_id = '" + trade_id + "';";
        if (flags.Contains("SLOWQUERY")) {
            sqlQuery = "SELECT *, pg_sleep(0.00001) FROM trades;";
            //sqlQuery = "SELECT * FROM trades;";
        }
        
        using (var cmd = ds.CreateCommand(sqlQuery))
        {
            using (var reader = cmd.ExecuteReader())
            {
                while (reader.Read())
                {
                    if (reader["trade_id"].ToString() == trade_id) {
                        string sku = rnd.Next(1000, 9999).ToString();
                        string employee_id = rnd.Next(1000, 9999).ToString();
                        string store_id = rnd.Next(1000, 9999).ToString();
                        string? region = Environment.GetEnvironmentVariable("REGION");
                        if (region != null) {
                            if (region.Contains("NA", StringComparison.OrdinalIgnoreCase))
                                store_id = rnd.Next(0, 4).ToString();
                            else if (region.Contains("EMEA", StringComparison.OrdinalIgnoreCase))
                                store_id = rnd.Next(5, 9).ToString();
                        }
                        logger.LogInformation("[" + DateTime.UtcNow.ToString("o") + "] TXTYPE:S, SKU:" + reader["symbol"].ToString() +", CUST_ID:" + reader["customer_id"].ToString() + ", EMPLY_ID:" +  employee_id + ", STOR_ID:" + store_id + ", REGION:" + region + ", PRICE:" + reader["share_price"].ToString());
                    }
                }
            }
        }
    }
}

string NotifyHandler([FromQuery] string? database, [FromQuery] string? trade_id, [FromQuery] string? flags, NpgsqlDataSource ds, ILogger<Program> logger)
{
    requestCounter.Add(1);
    Activity? currentActivity = Activity.Current;
    currentActivity?.SetTag($"{AttributePrefix}.flags", flags);

    if (!string.IsNullOrEmpty(database) && database == "postgresql") {
        try {
            QueryPostgresql(trade_id, flags, ds, logger);
        }
        catch (Exception e) {
            logger.LogWarning(e.ToString()); 
            logger.LogWarning("no conn avail");
        }
        //logger.LogInformation("notified+ " + database + trade_id);
    }

    //logger.LogInformation("notified");

    

    return "Notified";
}

app.MapGet("/health", HealthHandler);
app.MapPost("/notify", NotifyHandler);
await app.RunAsync();
