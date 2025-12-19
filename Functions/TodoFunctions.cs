using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using TodoApi.Data;
using TodoApi.Models;

namespace TodoApi.Functions;

public class TodoFunctions
{
    private readonly ILogger<TodoFunctions> _logger;
    private readonly TodoDb _db;

    public TodoFunctions(ILogger<TodoFunctions> logger, TodoDb db)
    {
        _logger = logger;
        _db = db;
    }

    [Function("GetAllTodos")]
    public async Task<IActionResult> GetAllTodos(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "todoitems")] HttpRequest req)
    {
        _logger.LogInformation("Getting all todo items");
        
        var todos = await _db.Todos
            .Select(t => new TodoItemDTO(t))
            .ToArrayAsync();
        
        return new OkObjectResult(todos);
    }

    [Function("GetCompleteTodos")]
    public async Task<IActionResult> GetCompleteTodos(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "todoitems/complete")] HttpRequest req)
    {
        _logger.LogInformation("Getting completed todo items");
        
        var todos = await _db.Todos
            .Where(t => t.IsComplete)
            .Select(t => new TodoItemDTO(t))
            .ToListAsync();
        
        return new OkObjectResult(todos);
    }

    [Function("GetTodoById")]
    public async Task<IActionResult> GetTodoById(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "todoitems/{id:int}")] HttpRequest req,
        int id)
    {
        _logger.LogInformation("Getting todo item with id: {Id}", id);
        
        var todo = await _db.Todos.FindAsync(id);
        
        if (todo is null)
        {
            return new NotFoundResult();
        }
        
        return new OkObjectResult(new TodoItemDTO(todo));
    }

    [Function("CreateTodo")]
    public async Task<IActionResult> CreateTodo(
        [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "todoitems")] HttpRequest req)
    {
        _logger.LogInformation("Creating new todo item");
        
        var todoItemDTO = await req.ReadFromJsonAsync<TodoItemDTO>();
        
        if (todoItemDTO is null)
        {
            return new BadRequestObjectResult("Invalid todo item");
        }
        
        var todoItem = new Todo
        {
            Name = todoItemDTO.Name,
            IsComplete = todoItemDTO.IsComplete
        };
        
        _db.Todos.Add(todoItem);
        await _db.SaveChangesAsync();
        
        var createdDto = new TodoItemDTO(todoItem);
        
        return new CreatedResult($"/todoitems/{todoItem.Id}", createdDto);
    }

    [Function("UpdateTodo")]
    public async Task<IActionResult> UpdateTodo(
        [HttpTrigger(AuthorizationLevel.Anonymous, "put", Route = "todoitems/{id:int}")] HttpRequest req,
        int id)
    {
        _logger.LogInformation("Updating todo item with id: {Id}", id);
        
        var todo = await _db.Todos.FindAsync(id);
        
        if (todo is null)
        {
            return new NotFoundResult();
        }
        
        var todoItemDTO = await req.ReadFromJsonAsync<TodoItemDTO>();
        
        if (todoItemDTO is null)
        {
            return new BadRequestObjectResult("Invalid todo item");
        }
        
        todo.Name = todoItemDTO.Name;
        todo.IsComplete = todoItemDTO.IsComplete;
        
        await _db.SaveChangesAsync();
        
        return new NoContentResult();
    }

    [Function("DeleteTodo")]
    public async Task<IActionResult> DeleteTodo(
        [HttpTrigger(AuthorizationLevel.Anonymous, "delete", Route = "todoitems/{id:int}")] HttpRequest req,
        int id)
    {
        _logger.LogInformation("Deleting todo item with id: {Id}", id);
        
        var todo = await _db.Todos.FindAsync(id);
        
        if (todo is null)
        {
            return new NotFoundResult();
        }
        
        _db.Todos.Remove(todo);
        await _db.SaveChangesAsync();
        
        return new NoContentResult();
    }
}

