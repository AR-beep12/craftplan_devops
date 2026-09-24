defmodule CraftplanWeb.ImportModalComponentTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @tag role: :admin
  test "sticky stepper, tabbed mapping, and footer actions", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/manage/settings/csv")

    view
    |> element("button[phx-click=open_import][phx-value-entity=products]")
    |> render_click()

    assert has_element?(view, "#csv-mapping-modal-content .sticky.top-0")
    assert has_element?(view, "#csv-mapping-modal-next")

    csv = "name,sku,price\nBread,BRD-1,abc"

    params = %{
      "delimiter" => ",",
      "dry_run" => "true",
      "csv_content" => csv
    }

    view
    |> element("#csv-select-form")
    |> render_submit(params)

    assert has_element?(view, "#csv-mapping-form")

    # defaults should map correctly to headers
    mapping_params = %{
      "mapping" => %{"name" => "name", "sku" => "sku", "price" => "price", "status" => ""}
    }

    view
    |> element("#csv-mapping-form")
    |> render_submit(mapping_params)

    # Errors should disable Next to Import
    assert has_element?(view, "#csv-mapping-modal-next-import[disabled]")
    # And Errors tab should show a table header
    assert has_element?(view, "#csv-mapping-modal-content thead th", "Fila")
  end

  defp run_import(conn, entity, csv, mapping) do
    {:ok, view, _html} = live(conn, ~p"/manage/settings/csv")

    view |> element("button[phx-click=open_import][phx-value-entity=#{entity}]") |> render_click()

    view
    |> element("#csv-select-form")
    |> render_submit(%{"delimiter" => ",", "dry_run" => "true", "csv_content" => csv})

    view |> element("#csv-mapping-form") |> render_submit(%{"mapping" => mapping})
    refute has_element?(view, "#csv-mapping-modal-next-import[disabled]")

    view |> element("#csv-mapping-modal-next-import") |> render_click()
    view |> element("#csv-mapping-modal-run-import") |> render_click()
    view
  end

  describe "full import wizard" do
    @tag role: :admin
    test "imports materials with color, quantity and description (no sku or price columns)", %{
      conn: conn,
      user: user
    } do
      name = "Harina #{System.unique_integer([:positive])}"
      csv = "name,unit,color,quantity,extra_description
#{name},gram,Blanco,10,Bolsa de 1kg"

      view =
        run_import(conn, "materials", csv, %{
          "name" => "name",
          "unit" => "unit",
          "color" => "color",
          "quantity" => "quantity",
          "extra_description" => "extra_description"
        })

      assert render(view) =~ "Se importaron 1"

      material = Enum.find(Craftplan.Inventory.list_materials!(actor: user), &(&1.name == name))
      assert material.color == "Blanco"
      assert material.extra_description == "Bolsa de 1kg"
    end

    @tag role: :admin
    test "imports customers without a type column", %{conn: conn, user: user} do
      email = "cliente#{System.unique_integer([:positive])}@test.com"
      csv = "first_name,last_name,email
Ana,Lopez,#{email}"

      view =
        run_import(conn, "customers", csv, %{
          "first_name" => "first_name",
          "last_name" => "last_name",
          "email" => "email"
        })

      assert render(view) =~ "Se importaron 1"

      assert Enum.any?(
               Craftplan.CRM.list_customers!(actor: user),
               &(to_string(&1.email) == email)
             )
    end

    @tag role: :admin
    test "imports products with name and price", %{conn: conn, user: user} do
      name = "Pan #{System.unique_integer([:positive])}"
      csv = "name,price
#{name},5.50"

      view = run_import(conn, "products", csv, %{"name" => "name", "price" => "price"})

      assert render(view) =~ "Se importaron 1"
      assert Enum.any?(Craftplan.Catalog.list_products!(actor: user), &(&1.name == name))
    end
  end
end
