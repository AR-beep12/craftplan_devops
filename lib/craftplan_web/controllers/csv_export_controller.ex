defmodule CraftplanWeb.CSVExportController do
  use CraftplanWeb, :controller

  @exporters %{
    "orders" => Craftplan.CSV.Exporters.Orders,
    "customers" => Craftplan.CSV.Exporters.Customers,
    "movements" => Craftplan.CSV.Exporters.Movements
  }

  def export(conn, %{"entity" => entity}) do
    case Map.fetch(@exporters, entity) do
      {:ok, exporter} ->
        actor = conn.assigns[:current_user]
        csv = exporter.export(actor)
        filename = "#{entity}_#{Date.to_iso8601(Date.utc_today())}.csv"

        conn
        |> put_resp_content_type("text/csv")
        |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
        |> send_resp(200, csv)

      :error ->
        conn
        |> put_flash(:error, "Entidad de exportación desconocida")
        |> redirect(to: ~p"/manage/settings/csv")
    end
  end

  @templates %{
    "products" => {"products_template.csv", "name,price\nPan de masa madre,45.50\n"},
    "materials" => {"materials_template.csv", "name,unit,color,quantity,extra_description\nHarina de trigo,kg,,100,\n"},
    "customers" => {"customers_template.csv", "first_name,last_name,phone,email\nMaria,Garcia,+525512345678,maria@example.com\n"}
  }

  def template(conn, %{"entity" => entity}) do
    case Map.fetch(@templates, entity) do
      {:ok, {filename, csv}} ->
        conn
        |> put_resp_content_type("text/csv")
        |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
        |> send_resp(200, csv)

      :error ->
        conn
        |> put_flash(:error, "Plantilla desconocida")
        |> redirect(to: ~p"/manage/settings/csv")
    end
  end
end
