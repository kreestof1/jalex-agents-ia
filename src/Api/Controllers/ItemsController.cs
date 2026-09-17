using Api.Models;
using Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ItemsController(IItemsService itemsService) : ControllerBase
{
    [HttpGet]
    public ActionResult<IReadOnlyList<Item>> GetAll() => Ok(itemsService.GetAll());

    [HttpGet("{id:int}")]
    public ActionResult<Item> GetById(int id)
    {
        var item = itemsService.GetById(id);
        return item is null ? NotFound() : Ok(item);
    }
}
