defmodule CraftplanWeb.OrderLive.Helpers do
  @moduledoc """
  Helper functions specific to the OrderLive module, focused on order-related
  calculations and view transformations.
  """

  import CraftplanWeb.HtmlHelpers

  @doc """
  Check if an order is urgent (due soon)
  """
  def is_urgent_order(order) do
    now = DateTime.utc_now()
    delivery_date = order.delivery_date

    # Calculate days until delivery
    days_until_delivery =
      delivery_date
      |> DateTime.diff(now, :second)
      |> Kernel./(86_400)
      |> Float.round(1)

    # Consider urgent if less than 2 days and not completed/cancelled
    days_until_delivery <= 2 &&
      order.status not in [:completed, :cancelled]
  end

  @doc """
  Spanish display label for an order status.
  """
  def order_status_label(:pending), do: "Pendiente"
  def order_status_label(:in_progress), do: "En progreso"
  def order_status_label(:completed), do: "Completado"
  def order_status_label(:cancelled), do: "Cancelado"

  def order_status_label(status) when is_binary(status), do: status |> String.to_existing_atom() |> order_status_label()

  def order_status_label(status), do: to_string(status)

  @doc """
  Spanish display label for an order payment status.
  """
  def payment_status_label(:paid), do: "Pagado"
  def payment_status_label(:pending), do: "Pendiente"
  def payment_status_label(:to_be_refunded), do: "Por reembolsar"
  def payment_status_label(:refunded), do: "Reembolsado"

  def payment_status_label(status) when is_binary(status),
    do: status |> String.to_existing_atom() |> payment_status_label()

  def payment_status_label(status), do: to_string(status)

  @doc """
  Spanish display label for an order item's derived fulfillment status.
  """
  def order_item_status_label(:todo), do: "Pendiente"
  def order_item_status_label(:in_progress), do: "En progreso"
  def order_item_status_label(:done), do: "Completado"
  def order_item_status_label(status), do: to_string(status)

  @doc """
  Create calendar events from orders
  """
  def create_calendar_events(orders, event_duration) do
    Enum.map(orders, fn order ->
      %{
        id: order.reference,
        title: "#{order.customer.full_name} - #{format_reference(order.reference)}",
        start: DateTime.to_iso8601(order.delivery_date),
        end:
          order.delivery_date
          |> DateTime.add(event_duration, :second)
          |> DateTime.to_iso8601(),
        color: get_status_color_hex(order.status),
        textColor: "#000",
        url: nil,
        # Additional separated information for further customization
        extendedProps: %{
          customer: %{
            name: order.customer.full_name,
            reference: order.customer.reference
          },
          order: %{
            reference: order.reference,
            status: order.status,
            payment_status: order.payment_status,
            total_cost: order.total_cost
          }
        }
      }
    end)
  end
end
