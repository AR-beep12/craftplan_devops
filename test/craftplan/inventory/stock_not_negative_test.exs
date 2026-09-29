defmodule Craftplan.Inventory.StockNotNegativeTest do
  use Craftplan.DataCase, async: true

  alias Craftplan.Inventory
  alias Decimal, as: D

  setup do
    actor = staff_actor()

    {:ok, material} =
      Inventory.Material
      |> Ash.Changeset.for_create(:create, %{name: "Stock Guard Material", unit: :gram})
      |> Ash.create(actor: actor)

    {:ok, lot} =
      Inventory.Lot
      |> Ash.Changeset.for_create(:create, %{
        lot_code: "LOT-#{System.unique_integer([:positive])}",
        material_id: material.id
      })
      |> Ash.create(actor: actor)

    %{actor: actor, material: material, lot: lot}
  end

  defp adjust(actor, attrs) do
    Inventory.Movement
    |> Ash.Changeset.for_create(:adjust_stock, attrs)
    |> Ash.create(actor: actor)
  end

  defp current_stock(material, actor) do
    Inventory.Material
    |> Ash.get!(material.id, actor: actor)
    |> Ash.load!(:current_stock, actor: actor)
    |> Map.fetch!(:current_stock)
  end

  defp current_lot_stock(lot, actor) do
    Inventory.Lot
    |> Ash.get!(lot.id, actor: actor)
    |> Ash.load!(:current_stock, actor: actor)
    |> Map.fetch!(:current_stock)
  end

  describe "material level" do
    test "allows adding stock", %{actor: actor, material: material} do
      assert {:ok, _movement} = adjust(actor, %{material_id: material.id, quantity: D.new("100")})
      assert {:ok, _movement} = adjust(actor, %{material_id: material.id, quantity: D.new("50")})

      assert current_stock(material, actor) == D.new("150")
    end

    test "allows subtracting down to exactly zero", %{actor: actor, material: material} do
      assert {:ok, _movement} = adjust(actor, %{material_id: material.id, quantity: D.new("10")})
      assert {:ok, _movement} = adjust(actor, %{material_id: material.id, quantity: D.new("-10")})

      assert current_stock(material, actor) == D.new("0")
    end

    test "allows subtracting partially", %{actor: actor, material: material} do
      assert {:ok, _movement} = adjust(actor, %{material_id: material.id, quantity: D.new("10")})

      assert {:ok, _movement} =
               adjust(actor, %{material_id: material.id, quantity: D.new("-2.5")})

      assert current_stock(material, actor) == D.new("7.5")
    end

    test "rejects subtracting more than available", %{actor: actor, material: material} do
      assert {:ok, _movement} = adjust(actor, %{material_id: material.id, quantity: D.new("10")})

      assert {:error, error} = adjust(actor, %{material_id: material.id, quantity: D.new("-11")})

      assert inspect(error.errors) =~ "Stock insuficiente"
      assert current_stock(material, actor) == D.new("10")
    end

    test "rejects subtracting from a material without movements", %{
      actor: actor,
      material: material
    } do
      assert {:error, error} = adjust(actor, %{material_id: material.id, quantity: D.new("-1")})

      assert inspect(error.errors) =~ "disponible: 0"
      assert (current_stock(material, actor) || D.new(0)) == D.new(0)
    end
  end

  describe "lot level" do
    test "allows consuming the whole lot down to zero", %{
      actor: actor,
      material: material,
      lot: lot
    } do
      assert {:ok, _movement} =
               adjust(actor, %{material_id: material.id, lot_id: lot.id, quantity: D.new("25")})

      assert {:ok, _movement} =
               adjust(actor, %{material_id: material.id, lot_id: lot.id, quantity: D.new("-25")})

      assert current_lot_stock(lot, actor) == D.new("0")
      assert current_stock(material, actor) == D.new("0")
    end

    test "rejects consuming more than the lot holds", %{
      actor: actor,
      material: material,
      lot: lot
    } do
      assert {:ok, _movement} =
               adjust(actor, %{material_id: material.id, lot_id: lot.id, quantity: D.new("25")})

      assert {:error, error} =
               adjust(actor, %{material_id: material.id, lot_id: lot.id, quantity: D.new("-25.5")})

      assert inspect(error.errors) =~ "del lote"
      assert current_lot_stock(lot, actor) == D.new("25")
    end
  end
end
