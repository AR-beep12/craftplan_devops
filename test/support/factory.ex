defmodule Craftplan.Test.Factory do
  @moduledoc """
  Minimal factories for common domain entities used in tests.
  Uses Ash actions and passes a default staff actor when needed.
  """

  alias Craftplan.Catalog.BOM
  alias Craftplan.Catalog.Product
  alias Craftplan.CRM.Customer
  alias Craftplan.Inventory.Allergen
  alias Craftplan.Inventory.Material
  alias Craftplan.Inventory.MaterialAllergen
  alias Craftplan.Orders.Order

  defp staff_actor, do: Craftplan.DataCase.staff_actor()

  # Products
  def create_product!(attrs \\ %{}, actor \\ staff_actor()) do
    params =
      %{
        name: Map.get(attrs, :name, "Test Product"),
        sku: Map.get(attrs, :sku, unique_code("SKU")),
        status: Map.get(attrs, :status, :active),
        price: Map.get(attrs, :price, Decimal.new("10.00"))
      }

    Product
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!(actor: actor)
  end

  # Materials & Allergens
  def create_material!(attrs \\ %{}, actor \\ staff_actor()) do
    params =
      %{
        name: Map.get(attrs, :name, "Test Material"),
        unit: Map.get(attrs, :unit, :piece),
        color: Map.get(attrs, :color, "rojo"),
        quantity: Map.get(attrs, :quantity, Decimal.new("10")),
        extra_description: Map.get(attrs, :extra_description, "desc extra #{System.unique_integer([:positive])}")
      }
      |> maybe_put(:sku, Map.get(attrs, :sku))
      |> maybe_put(:price, Map.get(attrs, :price))
      |> maybe_put(:minimum_stock, Map.get(attrs, :minimum_stock))
      |> maybe_put(:maximum_stock, Map.get(attrs, :maximum_stock))

    Material
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!(actor: actor)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  def add_allergen!(material, name \\ "Gluten", actor \\ staff_actor()) do
    allergen =
      Allergen |> Ash.Changeset.for_create(:create, %{name: name}) |> Ash.create!(actor: actor)

    _ =
      MaterialAllergen
      |> Ash.Changeset.for_create(:create, %{material_id: material.id, allergen_id: allergen.id})
      |> Ash.create!(actor: actor)

    Ash.reload!(material, load: [:allergens])
  end

  # Legacy name kept for compatibility: creates a BOM instead
  def create_recipe!(product, components, actor \\ staff_actor()) do
    bom_components =
      Enum.map(components, fn c ->
        %{
          component_type: :material,
          material_id: c["material_id"] || c[:material_id],
          quantity: c["quantity"] || c[:quantity]
        }
      end)

    BOM
    |> Ash.Changeset.for_create(:create, %{product_id: product.id, components: bom_components})
    |> Ash.create!(actor: actor)
  end

  # Customers
  def create_customer!(attrs \\ %{}, _actor \\ staff_actor()) do
    params =
      %{
        type: :individual,
        first_name: Map.get(attrs, :first_name, "Jane"),
        last_name: Map.get(attrs, :last_name, "Doe"),
        email: Map.get(attrs, :email, "jane.doe+#{System.unique_integer([:positive])}@local")
      }

    Customer
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!()
  end

  # Orders
  def create_order_with_items!(customer, items, opts \\ []) do
    actor = Keyword.get(opts, :actor, staff_actor())
    delivery_date = Keyword.get(opts, :delivery_date, DateTime.utc_now())

    params = %{
      customer_id: customer.id,
      delivery_date: delivery_date,
      items: items
    }

    {:ok, order} =
      Order
      |> Ash.Changeset.for_create(:create, params)
      |> Ash.create(actor: actor)

    Ash.reload!(order, load: [items: [product: [:name, :sku]]], actor: actor)
  end

  # API Keys
  def create_api_key!(scopes \\ %{}, actor \\ admin_actor()) do
    {:ok, api_key} =
      Craftplan.Accounts.create_api_key(
        %{name: "test-key-#{System.unique_integer([:positive])}", scopes: scopes},
        actor: actor
      )

    {Map.get(api_key, :__raw_key__), api_key}
  end

  defp admin_actor, do: Craftplan.DataCase.admin_actor()

  defp unique_code(prefix), do: String.downcase(prefix) <> "-" <> Ecto.UUID.generate()
end
