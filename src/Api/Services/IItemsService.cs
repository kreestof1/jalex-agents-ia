using Api.Models;

namespace Api.Services;

public interface IItemsService
{
    IReadOnlyList<Item> GetAll();

    Item? GetById(int id);
}
