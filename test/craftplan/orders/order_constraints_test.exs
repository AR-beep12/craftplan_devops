defmodule Craftplan.Orders.OrderConstraintsTest do
  use Craftplan.DataCase, async: true

  alias Craftplan.Catalog
  alias Craftplan.CRM
  alias Craftplan.Orders
  alias Craftplan.Settings

  setup do
    admin = Craftplan.DataCase.admin_actor()
    staff = Craftplan.DataCase.staff_actor()
    # Ensure a settings row exists with defaults
    {:ok, settings} =
      Settings.Settings |> Ash.Changeset.for_create(:init, %{}) |> Ash.create(actor: admin)

    {:ok, customer} =
      CRM.Customer
      |> Ash.Changeset.for_create(:create, %{
        first_name: "Jane",
        last_name: "Roe",
        email: "jane.roe@example.com"
      })
      |> Ash.create()

    {:ok, product} =
      Catalog.Product
      |> Ash.Changeset.for_create(:create, %{
        name: "Cap Product",
        price: Decimal.new("10.00")
      })
      |> Ash.create(actor: staff)

    {:ok, %{settings: settings, customer: customer, product: product}}
  end

  test "lead time is enforced", %{settings: settings, customer: customer, product: product} do
    admin = Craftplan.DataCase.admin_actor()
    # Set lead_time_days = 1
    {:ok, _} =
      settings
      |> Ash.Changeset.for_update(:update, %{lead_time_days: 1})
      |> Ash.update(actor: admin)

    items = [%{product_id: product.id, quantity: Decimal.new(1), unit_price: product.price}]

    # Today should fail
    {:error, changeset} =
      Orders.Order
      |> Ash.Changeset.for_create(:create, %{
        customer_id: customer.id,
        delivery_date: DateTime.new!(Date.utc_today(), ~T[09:00:00], "Etc/UTC"),
        items: items
      })
      |> Ash.create(actor: Craftplan.DataCase.staff_actor())

    assert changeset.errors |> inspect() |> String.contains?("delivery date must be on or after")

    # Tomorrow should pass
    {:ok, _order} =
      Orders.Order
      |> Ash.Changeset.for_create(:create, %{
        customer_id: customer.id,
        delivery_date: DateTime.new!(Date.add(Date.utc_today(), 1), ~T[09:00:00], "Etc/UTC"),
        items: items
      })
      |> Ash.create(actor: Craftplan.DataCase.staff_actor())
  end

  test "global daily capacity is enforced", %{
    settings: settings,
    customer: customer,
    product: product
  } do
    admin = Craftplan.DataCase.admin_actor()
    staff = Craftplan.DataCase.staff_actor()

    {:ok, _} =
      settings
      |> Ash.Changeset.for_update(:update, %{daily_capacity: 1})
      |> Ash.update(actor: admin)

    today_dt = DateTime.new!(Date.utc_today(), ~T[10:00:00], "Etc/UTC")
    items = [%{product_id: product.id, quantity: Decimal.new(1), unit_price: product.price}]

    {:ok, _o1} =
      Orders.Order
      |> Ash.Changeset.for_create(:create, %{
        customer_id: customer.id,
        delivery_date: today_dt,
        items: items
      })
      |> Ash.create(actor: staff)

    {:error, changeset} =
      Orders.Order
      |> Ash.Changeset.for_create(:create, %{
        customer_id: customer.id,
        delivery_date: today_dt,
        items: items
      })
      |> Ash.create(actor: staff)

    assert changeset.errors |> inspect() |> String.contains?("daily capacity reached")
  end
end
