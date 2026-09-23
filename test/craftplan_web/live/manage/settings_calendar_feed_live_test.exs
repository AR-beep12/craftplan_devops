defmodule CraftplanWeb.SettingsCalendarFeedLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Accounts

  defp admin_conn(conn) do
    admin = Craftplan.DataCase.admin_actor()

    conn =
      conn
      |> AshAuthentication.Phoenix.Plug.store_in_session(admin)
      |> Plug.Conn.assign(:current_user, admin)

    {conn, admin}
  end

  describe "calendar feed page" do
    test "renders calendar feed header and instructions", %{conn: conn} do
      {conn, _admin} = admin_conn(conn)

      {:ok, view, _html} = live(conn, ~p"/manage/settings/calendar")

      assert has_element?(view, "header", "Feed de calendario")
      assert has_element?(view, "h3", "Cómo suscribirse")
      assert has_element?(view, "h4", "Google Calendar")
      assert has_element?(view, "h4", "Apple Calendar")
    end

    test "shows empty state when no calendar feeds exist", %{conn: conn} do
      {conn, _admin} = admin_conn(conn)

      {:ok, view, _html} = live(conn, ~p"/manage/settings/calendar")

      assert has_element?(view, "div", "Aún no hay feeds de calendario")
      assert has_element?(view, "#generate-calendar-feed-btn", "Generar feed de calendario")
    end

    test "clicking Generate Calendar Feed creates key and shows subscription URL", %{conn: conn} do
      {conn, _admin} = admin_conn(conn)

      {:ok, view, _html} = live(conn, ~p"/manage/settings/calendar")

      view |> element("#generate-calendar-feed-btn") |> render_click()

      # Should show the full feed URL with the real API key
      assert has_element?(view, "#calendar-new-feed-url")
      html = render(view)
      assert html =~ "feed.ics?key=cpk_"
      assert html =~ "Copia esta URL ahora"
    end

    test "generated feed appears in the feeds table", %{conn: conn} do
      {conn, _admin} = admin_conn(conn)

      {:ok, view, _html} = live(conn, ~p"/manage/settings/calendar")

      view |> element("#generate-calendar-feed-btn") |> render_click()

      # Feed should appear in table
      assert has_element?(view, "#calendar-feeds", "Feed de calendario")
      assert has_element?(view, "#calendar-feeds", "Nunca")
    end

    test "lists existing suitable keys in the table", %{conn: conn} do
      {conn, admin} = admin_conn(conn)

      {:ok, api_key} =
        Accounts.create_api_key(
          %{name: "My Cal Key", scopes: %{"orders" => ["read"]}},
          actor: admin
        )

      {:ok, _view, html} = live(conn, ~p"/manage/settings/calendar")

      assert html =~ "My Cal Key"
      assert html =~ "#{api_key.prefix}"
    end

    test "does not list keys without orders:read scope", %{conn: conn} do
      {conn, admin} = admin_conn(conn)

      {:ok, _api_key} =
        Accounts.create_api_key(
          %{name: "Products Only", scopes: %{"products" => ["read"]}},
          actor: admin
        )

      {:ok, view, _html} = live(conn, ~p"/manage/settings/calendar")

      html = render(view)
      refute html =~ "Products Only"
      assert has_element?(view, "div", "Aún no hay feeds de calendario")
    end

    test "revoking a feed removes it from the list", %{conn: conn} do
      {conn, _admin} = admin_conn(conn)

      {:ok, view, _html} = live(conn, ~p"/manage/settings/calendar")

      # Create a feed first
      view |> element("#generate-calendar-feed-btn") |> render_click()
      assert has_element?(view, "#calendar-feeds", "Feed de calendario")

      # Revoke it
      view |> element("#calendar-feeds button", "Revocar") |> render_click()

      # Should show empty state again
      assert has_element?(view, "div", "Aún no hay feeds de calendario")
    end

    test "navigation shows Calendar Feed in settings sub-links", %{conn: conn} do
      {conn, _admin} = admin_conn(conn)

      {:ok, _view, html} = live(conn, ~p"/manage/settings/calendar")

      assert html =~ "Feed de calendario"
    end
  end
end
