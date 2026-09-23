defmodule CraftplanWeb.ManageProductionLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @tag role: :staff
  test "renders schedule tab", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/manage/production/schedule")
    assert has_element?(view, "#controls")
  end

  @tag role: :staff
  test "renders batches index", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/manage/production/batches")
    assert has_element?(view, "#batches-table")
  end
end
