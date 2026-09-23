defmodule CraftplanWeb.ManageSettingsForecastingLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "forecasting settings" do
    test "renders forecasting settings section", %{conn: conn} do
      admin = Craftplan.DataCase.admin_actor()

      conn =
        conn
        |> AshAuthentication.Phoenix.Plug.store_in_session(admin)
        |> Plug.Conn.assign(:current_user, admin)

      {:ok, _view, html} = live(conn, ~p"/manage/settings/general")

      assert html =~ "Pronóstico de inventario"
      assert html =~ "Días de historial"
      assert html =~ "Horizonte predeterminado"
      assert html =~ "Peso del uso real"
      assert html =~ "Peso del uso planificado"
      assert html =~ "Nivel de servicio predeterminado"
      assert html =~ "Muestras mínimas para variabilidad"
    end

    test "can update forecasting settings", %{conn: conn} do
      admin = Craftplan.DataCase.admin_actor()

      conn =
        conn
        |> AshAuthentication.Phoenix.Plug.store_in_session(admin)
        |> Plug.Conn.assign(:current_user, admin)

      {:ok, view, _html} = live(conn, ~p"/manage/settings/general")

      # Submit form with updated forecasting values
      view
      |> element("#settings-form")
      |> render_submit(%{
        "settings" => %{
          "forecast_lookback_days" => "30",
          "forecast_actual_weight" => "0.7",
          "forecast_planned_weight" => "0.3",
          "forecast_min_samples" => "15",
          "forecast_default_service_level" => "0.99",
          "forecast_default_horizon_days" => "21"
        }
      })

      assert render(view) =~ "Configuración actualizada correctamente"

      # Verify the values persisted
      {:ok, _view2, html} = live(conn, ~p"/manage/settings/general")

      assert html =~ "value=\"30\""
      assert html =~ "value=\"15\""
      assert html =~ "value=\"21\""
    end
  end
end
