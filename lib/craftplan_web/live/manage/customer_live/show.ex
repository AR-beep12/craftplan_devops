defmodule CraftplanWeb.CustomerLive.Show do
  @moduledoc false
  use CraftplanWeb, :live_view

  import CraftplanWeb.OrderLive.Helpers, only: [order_status_label: 1]

  alias Craftplan.CRM
  alias CraftplanWeb.Navigation

  @impl true
  def render(assigns) do
    assigns =
      assign_new(assigns, :breadcrumbs, fn -> [] end)

    ~H"""
    <.header>
      {@customer.full_name}
    </.header>

    <.sub_nav links={@tabs_links} />

    <div class="p mt-4 space-y-6">
      <.tabs_content :if={@live_action in [:details, :show]}>
        <div class="mt-8 space-y-8">
          <div class="grid grid-cols-1 gap-8 md:grid-cols-2">
            <.list>
              <:item title="Tipo"><.badge text={customer_type_label(@customer.type)} /></:item>
              <:item title="Nombre">{@customer.full_name}</:item>
              <:item title="Correo electrónico">{@customer.email}</:item>
              <:item title="Teléfono">{@customer.phone}</:item>
              <:item title="Dirección de facturación">
                {@customer.billing_address && @customer.billing_address.full_address}
              </:item>
              <:item title="Dirección de envío">
                {@customer.shipping_address && @customer.shipping_address.full_address}
              </:item>
            </.list>
          </div>
        </div>
      </.tabs_content>

      <.tabs_content :if={@live_action == :orders}>
        <div class="mt-6 space-y-4">
          <div class="flex items-center justify-between">
            <h3 class="text-lg font-semibold">Historial de pedidos</h3>
            <.link navigate={~p"/manage/orders/new?customer_id=#{@customer.reference}"}>
              <.button variant={:primary}>Nuevo pedido</.button>
            </.link>
          </div>

          <.table
            id="customer_orders"
            rows={@customer.orders}
            row_click={fn order -> JS.navigate(~p"/manage/orders/#{order.reference}") end}
          >
            <:col :let={order} label="Referencia">
              <.kbd>{order.reference}</.kbd>
            </:col>
            <:col :let={order} label="Estado">
              <.badge
                text={order_status_label(order.status)}
                value={order.status}
                colors={[
                  {order.status,
                   "#{order_status_color(order.status)} #{order_status_bg(order.status)}"}
                ]}
              />
            </:col>
            <:col :let={order} label="Creado">
              {format_time(order.inserted_at, @time_zone)}
            </:col>
            <:col :let={order} label="Fecha de entrega">
              {format_time(order.delivery_date, @time_zone)}
            </:col>
            <:col :let={order} label="Total">
              {format_money(@settings.currency, order.total_cost)}
            </:col>
          </.table>
        </div>
      </.tabs_content>

      <.tabs_content :if={@live_action == :statistics}>
        <div class="mt-6 space-y-8">
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
            <.stat_card title="Total de pedidos" value={@customer.total_orders} />

            <.stat_card
              title="Total gastado"
              value={format_money(@settings.currency, @customer.total_orders_value)}
            />
          </div>
        </div>
      </.tabs_content>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"reference" => reference}, _, socket) do
    customer =
      CRM.get_customer_by_reference!(
        reference,
        actor: socket.assigns.current_user,
        load: [
          :full_name,
          :total_orders_value,
          :total_orders,
          orders: [:total_cost, :total_items],
          billing_address: [:full_address],
          shipping_address: [:full_address]
        ]
      )

    live_action = socket.assigns.live_action

    tabs_links = [
      %{
        label: "Detalles",
        navigate: ~p"/manage/customers/#{customer.reference}/details",
        active: live_action in [:details, :show]
      },
      %{
        label: "Pedidos",
        navigate: ~p"/manage/customers/#{customer.reference}/orders",
        active: live_action == :orders
      },
      %{
        label: "Estadísticas",
        navigate: ~p"/manage/customers/#{customer.reference}/statistics",
        active: live_action == :statistics
      }
    ]

    socket =
      socket
      |> assign(:page_title, page_title(live_action))
      |> assign(:customer, customer)
      |> assign(:tabs_links, tabs_links)

    {:noreply, Navigation.assign(socket, :customers, customer_trail(customer, live_action))}
  end

  defp page_title(:show), do: "Detalles del cliente"
  defp page_title(:details), do: "Detalles del cliente"
  defp page_title(:orders), do: "Pedidos del cliente"
  defp page_title(:statistics), do: "Estadísticas del cliente"

  defp customer_trail(customer, :orders) do
    [
      Navigation.root(:customers),
      Navigation.resource(:customer, customer),
      Navigation.page(:customers, :customer_orders, customer)
    ]
  end

  defp customer_trail(customer, :statistics) do
    [
      Navigation.root(:customers),
      Navigation.resource(:customer, customer),
      Navigation.page(:customers, :customer_statistics, customer)
    ]
  end

  defp customer_trail(customer, _), do: [Navigation.root(:customers), Navigation.resource(:customer, customer)]

  defp customer_type_label(:individual), do: "Individual"
  defp customer_type_label(:company), do: "Empresa"

  defp customer_type_label(type) when is_binary(type),
    do: type |> String.to_existing_atom() |> customer_type_label()

  defp customer_type_label(type), do: to_string(type)
end
