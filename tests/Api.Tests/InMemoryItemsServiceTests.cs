using Api.Services;

namespace Api.Tests;

public class InMemoryItemsServiceTests
{
    private readonly InMemoryItemsService sut = new();

    [Fact]
    public void GetAll_ReturnsSeededItems()
    {
        var items = sut.GetAll();

        Assert.NotEmpty(items);
    }

    [Fact]
    public void GetById_WithExistingId_ReturnsItem()
    {
        var expected = sut.GetAll()[0];

        var actual = sut.GetById(expected.Id);

        Assert.Equal(expected, actual);
    }

    [Fact]
    public void GetById_WithUnknownId_ReturnsNull()
    {
        var actual = sut.GetById(-1);

        Assert.Null(actual);
    }
}
