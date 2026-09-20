defmodule Craftplan.CSV.MaterialsImporterTest do
  use Craftplan.DataCase, async: true

  alias Craftplan.CSV.Importers.Materials
  alias Craftplan.Inventory

  describe "dry_run/2" do
    test "returns error for invalid unit" do
      csv = "name,unit\nFlour,unknown\n"

      assert {:ok, %{rows: [], errors: errors}} =
               Materials.dry_run(csv, delimiter: ",", mapping: %{})

      assert Enum.any?(errors, &String.contains?(&1.message, "Invalid unit"))
    end
  end

  describe "import/2" do
    test "inserts or updates materials by name" do
      actor = Craftplan.DataCase.staff_actor()

      csv1 = "name,unit\nFlour,g\nMilk,ml\n"

      assert {:ok, %{inserted: 2, updated: 0, errors: []}} =
               Materials.import(csv1, delimiter: ",", mapping: %{}, actor: actor)

      assert {:ok, _} = Inventory.get_material_by_name("Flour", actor: actor)
      assert {:ok, _} = Inventory.get_material_by_name("Milk", actor: actor)

      # Update one (matched by name; upserter re-fetches by name, so name must be unchanged)
      csv2 = "name,unit,color\nFlour,g,rojo\n"

      assert {:ok, %{inserted: 0, updated: updated, errors: []}} =
               Materials.import(csv2, delimiter: ",", mapping: %{}, actor: actor)

      assert updated >= 1
    end
  end
end
