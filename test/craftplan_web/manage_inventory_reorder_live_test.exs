defmodule CraftplanWeb.ManageInventoryReorderLiveTest do
  # async: false + shared sandbox — the page computes metrics in a start_async
  # task; shared mode guarantees that task can reach the test's DB connection.
  use CraftplanWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup do
    Ecto.Adapters.SQL.Sandbox.mode(Craftplan.Repo, {:shared, self()})
    :ok
  end

  describe "async metrics load" do
  end
end
