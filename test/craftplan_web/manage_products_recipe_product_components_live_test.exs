defmodule CraftplanWeb.ManageProductsRecipeProductComponentsLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Catalog.BOM
  alias Craftplan.Catalog.Product
  alias Craftplan.Inventory.Material

  defp staff, do: Craftplan.DataCase.staff_actor()

  defp product!(attrs) do
    defaults = %{
      name: "P-#{System.unique_integer()}",
      price: Decimal.new("5.00")
    }

    Product
    |> Ash.Changeset.for_create(:create, Map.merge(defaults, attrs))
    |> Ash.create!(actor: staff())
  end

  defp material!(attrs \\ %{}) do
    defaults = %{
      name: "Mat-#{System.unique_integer()}",
      unit: :gram
    }

    Material
    |> Ash.Changeset.for_create(:create, Map.merge(defaults, attrs))
    |> Ash.create!(actor: staff())
  end

  defp product_with_bom!(attrs) do
    require Ash.Query

    m = material!()
    p = product!(attrs)

    BOM
    |> Ash.Changeset.for_create(:create, %{
      product_id: p.id,
      components: [%{component_type: :material, material_id: m.id, quantity: Decimal.new(10)}]
    })
    |> Ash.create!(actor: staff())

    # Reload product to get bom_unit_cost
    product_id = p.id

    Product
    |> Ash.Query.for_read(:read, %{})
    |> Ash.Query.filter(id == ^product_id)
    |> Ash.Query.load([:bom_unit_cost])
    |> Ash.read_one!(actor: staff())
  end
end
