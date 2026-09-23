defmodule CraftplanWeb.ManageProductsNutritionLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Catalog.BOM
  alias Craftplan.Catalog.Product
  alias Craftplan.Inventory.Material
  alias Craftplan.Inventory.MaterialNutritionalFact
  alias Craftplan.Inventory.Nutrition
  alias Craftplan.Inventory.NutritionalFact

  require Ash.Query

  defp staff, do: Craftplan.DataCase.staff_actor()

  defp product!(attrs \\ %{}) do
    Product
    |> Ash.Changeset.for_create(:create, %{
      name: "P-#{System.unique_integer()}",
      price: Decimal.new("5.00"),
      nutrition_output_quantity: Map.get(attrs, :nutrition_output_quantity),
      nutrition_output_unit: Map.get(attrs, :nutrition_output_unit)
    })
    |> Ash.create!(actor: staff())
  end

  defp material_with_fact! do
    material =
      Material
      |> Ash.Changeset.for_create(:create, %{
        name: "Mat-#{System.unique_integer()}",
        unit: :gram
      })
      |> Ash.create!(actor: staff())

    fact = fact!("Calories")

    _link =
      MaterialNutritionalFact
      |> Ash.Changeset.for_create(:create, %{
        material_id: material.id,
        nutritional_fact_id: fact.id,
        amount: Decimal.new("57"),
        unit: :kcal,
        basis_quantity: Decimal.new("100"),
        basis_unit: :gram
      })
      |> Ash.create!(actor: staff())

    Ash.reload!(material, load: [material_nutritional_facts: [nutritional_fact: [:name]]])
  end

  defp fact!(name) do
    key = Nutrition.standard_key_for_name(name) || Nutrition.custom_key(name)

    case NutritionalFact |> Ash.Query.filter(key == ^key) |> Ash.read_one!(authorize?: false) do
      nil ->
        NutritionalFact
        |> Ash.Changeset.for_create(:create, %{name: name})
        |> Ash.create!(actor: staff())

      fact ->
        fact
    end
  end
end
