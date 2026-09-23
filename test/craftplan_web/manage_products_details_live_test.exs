defmodule CraftplanWeb.ManageProductsDetailsLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Catalog.BOM
  alias Craftplan.Catalog.Product
  alias Craftplan.Inventory.Material

  defp staff, do: Craftplan.DataCase.staff_actor()

  defp product! do
    Product
    |> Ash.Changeset.for_create(:create, %{
      name: "P-#{System.unique_integer()}",
      price: Decimal.new("10.00")
    })
    |> Ash.create!(actor: staff())
  end

  defp material! do
    Material
    |> Ash.Changeset.for_create(:create, %{
      name: "Mat-#{System.unique_integer()}",
      unit: :gram
    })
    |> Ash.create!(actor: staff())
  end
end
