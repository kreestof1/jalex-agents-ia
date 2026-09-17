using Api.Models;

namespace Api.Services;

public class InMemoryItemsService : IItemsService
{
    private static readonly List<Item> Seed =
    [
        new Item(1, "Clavier mécanique", "Clavier mécanique 60% pour développeur"),
        new Item(2, "Souris ergonomique", "Souris verticale sans fil"),
        new Item(3, "Écran 27 pouces", "Écran 4K pour le développement")
    ];

    public IReadOnlyList<Item> GetAll() => Seed;

    public Item? GetById(int id) => Seed.SingleOrDefault(item => item.Id == id);
}
