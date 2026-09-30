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
      csv = "first_name,last_name,phone,email
Ana,Lopez,5551234567,#{email}"

      view =
        run_import(conn, "customers", csv, %{
          "first_name" => "first_name",
          "last_name" => "last_name",
          "phone" => "phone",
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

    @tag role: :admin
    test "honours the mapping chosen in the mapping step", %{conn: conn, user: user} do
      name = "Membrillo #{System.unique_integer([:positive])}"
      csv = "denominacion,importe\n#{name},8.25\n"

      view =
        run_import(conn, "products", csv, %{
          "name" => "denominacion",
          "price" => "importe"
        })

      assert render(view) =~ "Se importaron 1"
      assert Enum.any?(Craftplan.Catalog.list_products!(actor: user), &(&1.name == name))
    end
  end

  describe "file upload" do
    @tag role: :admin
    test "dropzone is wired to the file input", %{conn: conn} do
      view = open_import(conn, "products")

      # LiveView silently discards dropped files unless the container carries
      # phx-drop-target pointing at the id of the live file input.
      assert has_element?(view, "#csv-dropzone[phx-drop-target]")
      assert has_element?(view, "#csv-select-form input[type=file][data-phx-upload-ref]")

      html = render(view)

      [_, drop_target] = Regex.run(~r/id="csv-dropzone"[^>]*phx-drop-target="([^"]+)"/, html)
      [_, input_id] = Regex.run(~r/<input id="([^"]+)" type="file"/, html)

      assert drop_target == input_id
    end

    @tag role: :admin
    test "the select form declares phx-change so the browser starts the upload", %{conn: conn} do
      view = open_import(conn, "products")

      # LiveView bails out of the file input "input" event when neither the
      # input nor its form declares phx-change, so the upload never starts and
      # nothing shows up. Assert the attribute and a real change event.
      assert has_element?(view, "#csv-select-form[phx-change=csv_select_change]")

      view
      |> element("#csv-select-form")
      |> render_change(%{"delimiter" => ";", "dry_run" => "true", "csv_content" => ""})

      # No file uploaded yet, so the change event is a no-op and the wizard
      # stays on the first step.
      assert has_element?(view, "#csv-select-form")
      refute has_element?(view, "#csv-mapping-form")
    end

    @tag role: :admin
    test "loads the file automatically once it finishes uploading", %{conn: conn} do
      csv = "name,price\nHigo,4.75\n"

      view = open_import(conn, "products")

      upload = upload_csv(view, "higos.csv", "text/csv", csv)
      render_upload(upload, "higos.csv")

      # The upload finished on its own, so the wizard is already on the mapping
      # step without pressing "Siguiente".
      assert has_element?(view, "#csv-mapping-form")
    end

    @tag role: :admin
    test "shows a rejected file without taking down the LiveView", %{conn: conn} do
      csv = "name,price\nHigo,4.75\n"

      view = open_import(conn, "products")

      upload = upload_csv(view, "higos.xyz", "application/zip", csv)
      render_upload(upload, "higos.xyz")

      view
      |> element("#csv-select-form")
      |> render_submit(%{"delimiter" => ",", "dry_run" => "true"})

      assert Process.alive?(view.pid)
      refute has_element?(view, "#csv-mapping-form")
      refute has_element?(view, "#csv-upload-entries li")

      # The modal is still usable right after the rejection
      assert has_element?(view, "#csv-select-form")
    end
  end

  defp open_import(conn, entity) do
    {:ok, view, _html} = live(conn, ~p"/manage/settings/csv")

    view
    |> element("button[phx-click=open_import][phx-value-entity=#{entity}]")
    |> render_click()

    view
  end

  defp upload_csv(view, name, type, content) do
    file_input(view, "#csv-select-form", :csv, [
      %{
        last_modified: 1_594_171_879_000,
        name: name,
        content: content,
        size: byte_size(content),
        type: type
      }
    ])
  end
end
