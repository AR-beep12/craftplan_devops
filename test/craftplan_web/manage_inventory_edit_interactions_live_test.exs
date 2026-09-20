defmodule CraftplanWeb.ManageInventoryEditInteractionsLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Inventory.Material

  defp create_material! do
    Material
    |> Ash.Changeset.for_create(:create, %{
      name: "Mat-#{System.unique_integer()}",
      unit: :gram
    })
    |> Ash.create!(actor: Craftplan.DataCase.staff_actor())
  end

  @tag role: :staff
  test "edit material and save", %{conn: conn} do
    m = create_material!()
    {:ok, view, _} = live(conn, ~p"/manage/inventory/#{m.id}/edit")

    params = %{"material" => %{"name" => m.name <> "X"}}

    view
    |> element("#material-form")
    |> render_submit(params)

    assert_patch(view, ~p"/manage/inventory/#{m.id}/details")
    assert render(view) =~ "Material updated successfully"
  end
end
