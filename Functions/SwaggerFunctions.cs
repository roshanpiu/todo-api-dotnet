using System.Net;
using System.Text;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Microsoft.OpenApi;
using Microsoft.OpenApi.Extensions;
using Microsoft.OpenApi.Models;

namespace TodoApi.Functions;

public class SwaggerFunctions
{
    private readonly ILogger<SwaggerFunctions> _logger;
    private static OpenApiDocument? _openApiDocument;

    public SwaggerFunctions(ILogger<SwaggerFunctions> logger)
    {
        _logger = logger;
    }

    [Function("GetOpenApiSpec")]
    public IActionResult GetOpenApiSpec(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "swagger/v1/swagger.json")] HttpRequest req)
    {
        _logger.LogInformation("Serving OpenAPI specification");
        
        var document = GetOpenApiDocument(req);
        var json = document.SerializeAsJson(OpenApiSpecVersion.OpenApi3_0);
        
        return new ContentResult
        {
            Content = json,
            ContentType = "application/json",
            StatusCode = (int)HttpStatusCode.OK
        };
    }

    [Function("SwaggerUI")]
    public IActionResult SwaggerUI(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "swagger")] HttpRequest req)
    {
        _logger.LogInformation("Serving Swagger UI");
        
        var baseUrl = GetBaseUrl(req);
        var html = GetSwaggerUIHtml(baseUrl);
        
        return new ContentResult
        {
            Content = html,
            ContentType = "text/html",
            StatusCode = (int)HttpStatusCode.OK
        };
    }

    [Function("SwaggerUIIndex")]
    public IActionResult SwaggerUIIndex(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "swagger/index.html")] HttpRequest req)
    {
        return SwaggerUI(req);
    }

    private static string GetBaseUrl(HttpRequest req)
    {
        var scheme = req.Scheme;
        var host = req.Host.Value;
        return $"{scheme}://{host}";
    }

    private static OpenApiDocument GetOpenApiDocument(HttpRequest req)
    {
        if (_openApiDocument != null)
            return _openApiDocument;

        var baseUrl = GetBaseUrl(req);

        _openApiDocument = new OpenApiDocument
        {
            Info = new OpenApiInfo
            {
                Version = "v1",
                Title = "Todo API",
                Description = "A simple Todo API built with Azure Functions and .NET 9",
                Contact = new OpenApiContact
                {
                    Name = "API Support",
                    Url = new Uri("https://github.com/roshanpiu/todo-api-dotnet")
                }
            },
            Servers = new List<OpenApiServer>
            {
                new() { Url = baseUrl, Description = "Current Server" }
            },
            Paths = new OpenApiPaths
            {
                ["/todoitems"] = new OpenApiPathItem
                {
                    Operations = new Dictionary<OperationType, OpenApiOperation>
                    {
                        [OperationType.Get] = new OpenApiOperation
                        {
                            Tags = new List<OpenApiTag> { new() { Name = "Todo" } },
                            Summary = "Get all todo items",
                            Description = "Returns a list of all todo items",
                            OperationId = "GetAllTodos",
                            Responses = new OpenApiResponses
                            {
                                ["200"] = new OpenApiResponse
                                {
                                    Description = "Success",
                                    Content = new Dictionary<string, OpenApiMediaType>
                                    {
                                        ["application/json"] = new OpenApiMediaType
                                        {
                                            Schema = new OpenApiSchema
                                            {
                                                Type = "array",
                                                Items = new OpenApiSchema { Reference = new OpenApiReference { Type = ReferenceType.Schema, Id = "TodoItemDTO" } }
                                            }
                                        }
                                    }
                                }
                            }
                        },
                        [OperationType.Post] = new OpenApiOperation
                        {
                            Tags = new List<OpenApiTag> { new() { Name = "Todo" } },
                            Summary = "Create a new todo item",
                            Description = "Creates a new todo item and returns the created item",
                            OperationId = "CreateTodo",
                            RequestBody = new OpenApiRequestBody
                            {
                                Required = true,
                                Content = new Dictionary<string, OpenApiMediaType>
                                {
                                    ["application/json"] = new OpenApiMediaType
                                    {
                                        Schema = new OpenApiSchema { Reference = new OpenApiReference { Type = ReferenceType.Schema, Id = "TodoItemDTO" } }
                                    }
                                }
                            },
                            Responses = new OpenApiResponses
                            {
                                ["201"] = new OpenApiResponse
                                {
                                    Description = "Created",
                                    Content = new Dictionary<string, OpenApiMediaType>
                                    {
                                        ["application/json"] = new OpenApiMediaType
                                        {
                                            Schema = new OpenApiSchema { Reference = new OpenApiReference { Type = ReferenceType.Schema, Id = "TodoItemDTO" } }
                                        }
                                    }
                                },
                                ["400"] = new OpenApiResponse { Description = "Bad Request" }
                            }
                        }
                    }
                },
                ["/todoitems/complete"] = new OpenApiPathItem
                {
                    Operations = new Dictionary<OperationType, OpenApiOperation>
                    {
                        [OperationType.Get] = new OpenApiOperation
                        {
                            Tags = new List<OpenApiTag> { new() { Name = "Todo" } },
                            Summary = "Get completed todo items",
                            Description = "Returns a list of all completed todo items",
                            OperationId = "GetCompleteTodos",
                            Responses = new OpenApiResponses
                            {
                                ["200"] = new OpenApiResponse
                                {
                                    Description = "Success",
                                    Content = new Dictionary<string, OpenApiMediaType>
                                    {
                                        ["application/json"] = new OpenApiMediaType
                                        {
                                            Schema = new OpenApiSchema
                                            {
                                                Type = "array",
                                                Items = new OpenApiSchema { Reference = new OpenApiReference { Type = ReferenceType.Schema, Id = "TodoItemDTO" } }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                },
                ["/todoitems/{id}"] = new OpenApiPathItem
                {
                    Parameters = new List<OpenApiParameter>
                    {
                        new()
                        {
                            Name = "id",
                            In = ParameterLocation.Path,
                            Required = true,
                            Schema = new OpenApiSchema { Type = "integer", Format = "int32" },
                            Description = "The todo item ID"
                        }
                    },
                    Operations = new Dictionary<OperationType, OpenApiOperation>
                    {
                        [OperationType.Get] = new OpenApiOperation
                        {
                            Tags = new List<OpenApiTag> { new() { Name = "Todo" } },
                            Summary = "Get a todo item by ID",
                            Description = "Returns a single todo item",
                            OperationId = "GetTodoById",
                            Responses = new OpenApiResponses
                            {
                                ["200"] = new OpenApiResponse
                                {
                                    Description = "Success",
                                    Content = new Dictionary<string, OpenApiMediaType>
                                    {
                                        ["application/json"] = new OpenApiMediaType
                                        {
                                            Schema = new OpenApiSchema { Reference = new OpenApiReference { Type = ReferenceType.Schema, Id = "TodoItemDTO" } }
                                        }
                                    }
                                },
                                ["404"] = new OpenApiResponse { Description = "Not Found" }
                            }
                        },
                        [OperationType.Put] = new OpenApiOperation
                        {
                            Tags = new List<OpenApiTag> { new() { Name = "Todo" } },
                            Summary = "Update a todo item",
                            Description = "Updates an existing todo item",
                            OperationId = "UpdateTodo",
                            RequestBody = new OpenApiRequestBody
                            {
                                Required = true,
                                Content = new Dictionary<string, OpenApiMediaType>
                                {
                                    ["application/json"] = new OpenApiMediaType
                                    {
                                        Schema = new OpenApiSchema { Reference = new OpenApiReference { Type = ReferenceType.Schema, Id = "TodoItemDTO" } }
                                    }
                                }
                            },
                            Responses = new OpenApiResponses
                            {
                                ["204"] = new OpenApiResponse { Description = "No Content" },
                                ["400"] = new OpenApiResponse { Description = "Bad Request" },
                                ["404"] = new OpenApiResponse { Description = "Not Found" }
                            }
                        },
                        [OperationType.Delete] = new OpenApiOperation
                        {
                            Tags = new List<OpenApiTag> { new() { Name = "Todo" } },
                            Summary = "Delete a todo item",
                            Description = "Deletes a todo item by ID",
                            OperationId = "DeleteTodo",
                            Responses = new OpenApiResponses
                            {
                                ["204"] = new OpenApiResponse { Description = "No Content" },
                                ["404"] = new OpenApiResponse { Description = "Not Found" }
                            }
                        }
                    }
                }
            },
            Components = new OpenApiComponents
            {
                Schemas = new Dictionary<string, OpenApiSchema>
                {
                    ["TodoItemDTO"] = new OpenApiSchema
                    {
                        Type = "object",
                        Properties = new Dictionary<string, OpenApiSchema>
                        {
                            ["id"] = new OpenApiSchema
                            {
                                Type = "integer",
                                Format = "int32",
                                Description = "The unique identifier for the todo item",
                                ReadOnly = true
                            },
                            ["name"] = new OpenApiSchema
                            {
                                Type = "string",
                                Description = "The name/description of the todo item",
                                Nullable = true,
                                Example = new Microsoft.OpenApi.Any.OpenApiString("Buy groceries")
                            },
                            ["isComplete"] = new OpenApiSchema
                            {
                                Type = "boolean",
                                Description = "Whether the todo item is completed",
                                Default = new Microsoft.OpenApi.Any.OpenApiBoolean(false)
                            }
                        },
                        Required = new HashSet<string> { "name" }
                    }
                }
            }
        };

        return _openApiDocument;
    }

    private static string GetSwaggerUIHtml(string baseUrl)
    {
        return $@"<!DOCTYPE html>
<html lang=""en"">
<head>
    <meta charset=""UTF-8"">
    <meta name=""viewport"" content=""width=device-width, initial-scale=1.0"">
    <title>Todo API - Swagger UI</title>
    <link rel=""stylesheet"" type=""text/css"" href=""https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui.css"">
    <style>
        html {{ box-sizing: border-box; overflow-y: scroll; }}
        *, *:before, *:after {{ box-sizing: inherit; }}
        body {{ margin: 0; background: #fafafa; }}
        .swagger-ui .topbar {{ display: none; }}
        .swagger-ui .info {{ margin: 30px 0; }}
        .swagger-ui .info .title {{ font-size: 2.5em; }}
    </style>
</head>
<body>
    <div id=""swagger-ui""></div>
    <script src=""https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui-bundle.js""></script>
    <script src=""https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui-standalone-preset.js""></script>
    <script>
        window.onload = function() {{
            const ui = SwaggerUIBundle({{
                url: ""{baseUrl}/swagger/v1/swagger.json"",
                dom_id: '#swagger-ui',
                deepLinking: true,
                presets: [
                    SwaggerUIBundle.presets.apis,
                    SwaggerUIStandalonePreset
                ],
                plugins: [
                    SwaggerUIBundle.plugins.DownloadUrl
                ],
                layout: ""StandaloneLayout"",
                tryItOutEnabled: true,
                supportedSubmitMethods: ['get', 'post', 'put', 'delete', 'patch']
            }});
            window.ui = ui;
        }};
    </script>
</body>
</html>";
    }
}

