defmodule CraftplanWeb.ManageInventoryInteractionsLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Inventory.Allergen
  alias Craftplan.Inventory.Material
  alias Craftplan.Inventory.NutritionalFact

  defp create_material! do
    Material
    |> Ash.Changeset.for_create(:create, %{
      name: "Mat-#{System.unique_integer()}",
      unit: :gram
    })
    |> Ash.create!(actor: Craftplan.DataCase.staff_actor())
  end

  defp create_allergen! do
    Allergen
    |> Ash.Changeset.for_create(:create, %{name: "ALG-#{System.unique_integer()}"})
    |> Ash.create!(actor: Craftplan.DataCase.staff_actor())
  end

  defp create_nf! do
    NutritionalFact
    |> Ash.Changeset.for_create(:create, %{name: "NF-#{System.unique_integer()}"})
    |> Ash.create!(actor: Craftplan.DataCase.staff_actor())
  end

  @tag role: :staff
  test "adjust stock via set_total", %{conn: conn} do
    m = create_material!()
    {:ok, view, _} = live(conn, ~p"/manage/inventory/#{m.id}/adjust")

    params = %{"movement" => %{"material_id" => m.id, "quantity" => "5", "reason" => "test"}}

    view
    |> element("#movement-form")
    |> render_submit(params)

    assert_patch(view, ~p"/manage/inventory/#{m.id}/stock")
    assert render(view) =~ "Ajuste de stock registrado"
  end

  @tag role: :staff
  test "adjust stock via add", %{conn: conn} do
    m = create_material!()
    {:ok, view, _} = live(conn, ~p"/manage/inventory/#{m.id}/adjust")

    view
    |> element("button[phx-click=set_mode][phx-value-mode=add]")
    |> render_click()

    params = %{"movement" => %{"material_id" => m.id, "quantity" => "2", "reason" => "add"}}

    view
    |> element("#movement-form")
    |> render_submit(params)

    assert_patch(view, ~p"/manage/inventory/#{m.id}/stock")
    assert render(view) =~ "Ajuste de stock registrado"
  end

  @tag role: :staff
  test "adjust stock via subtract", %{conn: conn} do
    m = create_material!()
    {:ok, view, _} = live(conn, ~p"/manage/inventory/#{m.id}/adjust")

    view
    |> element("button[phx-click=set_mode][phx-value-mode=subtract]")
    |> render_click()

    params = %{"movement" => %{"material_id" => m.id, "quantity" => "1", "reason" => "sub"}}

    view
    |> element("#movement-form")
    |> render_submit(params)

    assert_patch(view, ~p"/manage/inventory/#{m.id}/stock")
    assert render(view) =~ "Ajuste de stock registrado"
  end
end
