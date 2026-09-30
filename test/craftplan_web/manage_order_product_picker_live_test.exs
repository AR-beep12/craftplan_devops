defmodule CraftplanWeb.ManageOrderProductPickerLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Test.Factory

  defp create_products! do
    %{
      soap: Factory.create_product!(%{name: "Jabón Facial"}),
      cream: Factory.create_product!(%{name: "Crema Hidratante"})
    }
  end

  defp search(view, query) do
    view
    |> element("#product-picker")
    |> render_keyup(%{"key" => "k", "value" => query})
  end

  describe "searchable product picker" do
    @tag role: :staff
    test "replaces the plain select with a search field holding the first product", %{conn: conn} do
      _products = create_products!()
      _customer = Factory.create_customer!()

      {:ok, view, _html} = live(conn, ~p"/manage/orders/new")

      assert has_element?(view, "#product-picker")
      assert has_element?(view, "input#product-picker[phx-keyup=search_product]")
      refute has_element?(view, "select#product-picker")
    end

    @tag role: :staff
    test "filters the options as the user types and reports no matches", %{conn: conn} do
      products = create_products!()
      _customer = Factory.create_customer!()

      {:ok, view, _html} = live(conn, ~p"/manage/orders/new")

      search(view, "Hidr")

      assert has_element?(
               view,
               "#product-select-widget button[phx-value-id='#{products.cream.id}']"
             )

      refute has_element?(
               view,
               "#product-select-widget button[phx-value-id='#{products.soap.id}']"
             )

      search(view, "zzz")

      refute has_element?(
               view,
               "#product-select-widget button[phx-value-id='#{products.soap.id}']"
             )

      assert has_element?(view, "#product-select-widget div", "Sin resultados")
    end

    @tag role: :staff
    test "adds the searched product to the order items and drops it from the options", %{
      conn: conn
    } do
      products = create_products!()
      _customer = Factory.create_customer!()

      {:ok, view, _html} = live(conn, ~p"/manage/orders/new")

      search(view, "Hidr")

      view
      |> element("#product-select-widget button[phx-value-id='#{products.cream.id}']")
      |> render_click()

      refute has_element?(view, "#product-select-widget button[phx-click=select_product]")

      assert view |> element("#product-picker") |> render() =~ "Crema Hidratante"

      view
      |> element("button[phx-click=add_form]")
      |> render_click()

      assert has_element?(view, "#order-items", "Crema Hidratante")

      search(view, "Hidr")

      assert has_element?(view, "#product-select-widget div", "Sin resultados")
    end
  end
end
