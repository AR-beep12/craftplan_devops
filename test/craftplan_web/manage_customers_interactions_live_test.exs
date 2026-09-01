defmodule CraftplanWeb.ManageCustomersInteractionsLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.CRM.Customer

  defp create_customer! do
    Customer
    |> Ash.Changeset.for_create(:create, %{
      first_name: "Ada",
      last_name: "Lovelace",
      email: "ada+#{System.unique_integer()}@local"
    })
    |> Ash.create!()
  end

  @tag role: :staff
  test "new customer button opens modal and submits form", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/manage/customers")

    view
    |> element("a[href='/manage/customers/new']")
    |> render_click()

    assert_patch(view, ~p"/manage/customers/new")
    assert has_element?(view, "#customer-modal")

    unique = System.unique_integer()
    email = "test+#{unique}@example.com"

    params = %{
      "customer" => %{
        "first_name" => "Test",
        "last_name" => "Customer#{unique}",
        "email" => email,
        "phone" => "+1234567890"
      }
    }

    view
    |> element("#customer-form")
    |> render_submit(params)

    assert render(view) =~ "Customer created successfully"
    assert render(view) =~ email
  end

  @tag role: :staff
  test "customer orders tab 'New Order' navigates to orders/new", %{conn: conn} do
    c = create_customer!()

    {:ok, view, _} = live(conn, ~p"/manage/customers/#{c.reference}/orders")

    view
    |> element("a[href='/manage/orders/new?customer_id=#{c.reference}']")
    |> render_click()

    assert_redirect(view, ~p"/manage/orders/new?customer_id=#{c.reference}")
  end
end
