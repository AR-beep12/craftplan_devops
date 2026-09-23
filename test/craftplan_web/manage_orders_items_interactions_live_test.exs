defmodule CraftplanWeb.ManageOrdersItemsInteractionsLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Catalog.BOM
  alias Craftplan.Catalog.Product
  alias Craftplan.Inventory.Material
  alias Craftplan.Orders.Order

  defp create_material! do
    Material
    |> Ash.Changeset.for_create(:create, %{
      name: "Mat-#{System.unique_integer()}",
      unit: :gram
    })
    |> Ash.create!(actor: Craftplan.DataCase.staff_actor())
  end

  defp create_product_with_recipe!(material) do
    prod =
      Product
      |> Ash.Changeset.for_create(:create, %{
        name: "P-#{System.unique_integer()}",
        price: Decimal.new("3.00")
      })
      |> Ash.create!(actor: Craftplan.DataCase.staff_actor())

    _bom =
      BOM
      |> Ash.Changeset.for_create(:create, %{
        product_id: prod.id,
        components: [
          %{"component_type" => :material, "material_id" => material.id, "quantity" => 1}
        ]
      })
      |> Ash.create!()

    prod
  end

  defp create_order_with_item!(product) do
    Order
    |> Ash.Changeset.for_create(:create, %{
      customer_id:
        Craftplan.CRM.Customer
        |> Ash.Changeset.for_create(:create, %{
          first_name: "Ada",
          last_name: "Lovelace"
        })
        |> Ash.create!()
        |> Map.fetch!(:id),
      delivery_date: DateTime.utc_now(),
      items: [%{"product_id" => product.id, "quantity" => 1, "unit_price" => product.price}]
    })
    |> Ash.create!(actor: Craftplan.DataCase.staff_actor())
  end
end
