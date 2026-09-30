defmodule CraftplanWeb.ManageOrdersTableLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Orders
  alias Craftplan.Test.Factory

  defp create_order!(first_name) do
    customer = Factory.create_customer!(%{first_name: first_name, last_name: "Table"})
    product = Factory.create_product!()

    Factory.create_order_with_items!(customer, [
      %{product_id: product.id, quantity: 1, unit_price: product.price}
    ])
  end

  defp set_status!(order, status) do
    Orders.update_order_status!(order, %{status: status}, actor: Craftplan.DataCase.staff_actor())
  end

  describe "status badges" do
    @tag role: :staff
    test "pending orders get the orange badge instead of the gray fallback", %{conn: conn} do
      _order = create_order!("PendingBadge")

      {:ok, view, _html} = live(conn, ~p"/manage/orders")

      assert has_element?(
               view,
               "#orders span.bg-orange-50.text-orange-700.border-orange-600",
               "Pendiente"
             )
    end

    @tag role: :staff
    test "completed orders get the green badge", %{conn: conn} do
      order = create_order!("CompletedBadge")
      set_status!(order, :completed)

      {:ok, view, _html} = live(conn, ~p"/manage/orders")

      assert has_element?(
               view,
               "#orders span.bg-emerald-50.text-emerald-700.border-emerald-600",
               "Completado"
             )
    end

    @tag role: :staff
    test "cancelled orders get the red badge", %{conn: conn} do
      order = create_order!("CancelledBadge")
      set_status!(order, :cancelled)

      {:ok, view, _html} = live(conn, ~p"/manage/orders")

      assert has_element?(
               view,
               "#orders span.bg-red-50.text-rose-700.border-rose-600",
               "Cancelado"
             )
    end
  end

  describe "empty state" do
    @tag role: :staff
    test "is not rendered when the table has orders", %{conn: conn} do
      _order = create_order!("Populated")

      {:ok, view, _html} = live(conn, ~p"/manage/orders")

      refute has_element?(view, "#orders-empty")
    end

    @tag role: :staff
    test "appears when a filter matches nothing and goes away on reset", %{conn: conn} do
      _order = create_order!("Resettable")

      {:ok, view, _html} = live(conn, ~p"/manage/orders")

      view
      |> element("#filters-form")
      |> render_change(%{"filters" => %{"customer_name" => "Nobody"}})

      assert has_element?(view, "#orders-empty")

      view
      |> element("button[phx-click*='reset_filters']")
      |> render_click()

      refute has_element?(view, "#orders-empty")
      assert has_element?(view, "#orders", "Resettable Table")
    end

    @tag role: :staff
    test "stays hidden while a status filter still matches", %{conn: conn} do
      _order = create_order!("StatusFiltered")

      {:ok, view, _html} = live(conn, ~p"/manage/orders")

      view
      |> element("#filters-form")
      |> render_change(%{"filters" => %{"status" => ["pending"]}})

      refute has_element?(view, "#orders-empty")
      assert has_element?(view, "#orders", "StatusFiltered Table")

      view
      |> element("#filters-form")
      |> render_change(%{"filters" => %{"status" => ["completed"]}})

      assert has_element?(view, "#orders-empty")
    end
  end
end
