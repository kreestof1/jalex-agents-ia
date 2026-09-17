using Api.Controllers;
using Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Api.Tests;

public class ItemsControllerTests
{
    private readonly ItemsController sut = new(new InMemoryItemsService());

    [Fact]
    public void GetAll_ReturnsOkWithItems()
    {
        var result = sut.GetAll();

        var okResult = Assert.IsType<OkObjectResult>(result.Result);
        Assert.NotEmpty(Assert.IsAssignableFrom<IReadOnlyList<Api.Models.Item>>(okResult.Value));
    }

    [Fact]
    public void GetById_WithExistingId_ReturnsOk()
    {
        var result = sut.GetById(1);

        Assert.IsType<OkObjectResult>(result.Result);
    }

    [Fact]
    public void GetById_WithUnknownId_ReturnsNotFound()
    {
        var result = sut.GetById(999);

        Assert.IsType<NotFoundResult>(result.Result);
    }
}
