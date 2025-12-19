using Microsoft.Azure.Functions.Worker;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using TodoApi.Data;
using TodoApi.Models;

var host = new HostBuilder()
    .ConfigureFunctionsWebApplication(builder =>
    {
        // Configure routing for minimal API style endpoints
    })
    .ConfigureServices((context, services) =>
    {
        services.AddApplicationInsightsTelemetryWorkerService();
        services.ConfigureFunctionsApplicationInsights();

        // Database configuration
        var connectionString = Environment.GetEnvironmentVariable("SqlConnectionString");
        
        if (string.IsNullOrEmpty(connectionString) || 
            Environment.GetEnvironmentVariable("UseInMemoryDatabase") == "true")
        {
            // Use InMemory database for local development
            services.AddDbContext<TodoDb>(options =>
                options.UseInMemoryDatabase("TodoList"));
        }
        else
        {
            // Use SQL Server for production
            services.AddDbContext<TodoDb>(options =>
                options.UseSqlServer(connectionString));
        }
    })
    .Build();

// Ensure database is created (create tables if they don't exist)
using (var scope = host.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<TodoDb>();
    db.Database.EnsureCreated();
}

host.Run();
