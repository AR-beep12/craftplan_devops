defmodule Craftplan.CSV.ProductsImporterTest do
  use Craftplan.DataCase, async: true

  alias Craftplan.CSV.Importers.Products

  describe "dry_run/2" do
    test "returns errors on invalid rows and no rows on failure" do
      csv = "name,price\nBad,xxx\n"

      assert {:ok, %{rows: rows, errors: errors}} =
               Products.dry_run(csv, delimiter: ",", mapping: %{})

      assert rows == []
      assert length(errors) == 1
      assert Enum.any?(errors, &String.contains?(&1.message, "Invalid price"))
    end
  end

  describe "import/2" do
    test "inserts new products and updates existing ones" do
      actor = Craftplan.DataCase.staff_actor()

      csv1 = "name,price\nProd A,1.00\nProd B,2.50\n"

      assert {:ok, %{inserted: 2, updated: 0, errors: []}} =
               Products.import(csv1, delimiter: ",", mapping: %{}, actor: actor)

      # Update one
      csv2 = "name,price\nProd A,1.25\nProd B,2.50\n"

      assert {:ok, %{inserted: 0, updated: updated, errors: []}} =
               Products.import(csv2, delimiter: ",", mapping: %{}, actor: actor)

      assert updated >= 1
    end
  end
end
