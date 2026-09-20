defmodule CraftplanWeb.OrderLive.Show do
  @moduledoc false
  use CraftplanWeb, :live_view

  import CraftplanWeb.OrderLive.Helpers

  alias Craftplan.Catalog
  alias Craftplan.Catalog.Product.Photo
  alias Craftplan.CRM
  alias Craftplan.Orders
  alias CraftplanWeb.Navigation

  @default_order_load [
    :total_cost,
    items: [
      :cost,
      :status,
      product: [:name]
    ],
    customer: [:full_name]
  ]

  @impl true
  def render(assigns) do
    assigns =
      assign_new(assigns, :breadcrumbs, fn -> [] end)

    ~H"""
    <.header>
      {@order.reference}
      <:actions>
        <div class="flex flex-wrap items-center gap-3">
          <.link patch={~p"/manage/orders/#{@order.reference}/edit"} phx-click={JS.push_focus()}>
            <.button variant={:primary}>Editar pedido</.button>
          </.link>
          <form phx-change="change_status" class="w-44">
            <.input
              name="new_status"
              type="select"
              value={Atom.to_string(@order.status)}
              options={[
                {"Pendiente", "pending"},
                {"En progreso", "in_progress"},
                {"Completado", "completed"},
                {"Cancelado", "cancelled"}
              ]}
              class="w-auto text-sm"
            />
          </form>
        </div>
      </:actions>
    </.header>

    <.sub_nav links={@tabs_links} />

    <div class="mt-4 space-y-6">
      <.tabs_content :if={@live_action in [:details, :show, :edit]}>
        <.list>
          <:item title="Referencia">
            <.kbd>
              {format_reference(@order.reference)}
            </.kbd>
          </:item>

          <:item title="Estado">
            <div class="flex items-center gap-2">
              <.badge
                text={order_status_label(@order.status)}
                colors={[
                  {@order.status,
                   "#{order_status_color(@order.status)} #{order_status_bg(@order.status)}"}
                ]}
              />
            </div>
          </:item>

          <:item title="Cliente">
            <.link
              class="hover:text-blue-800 hover:underline"
              navigate={~p"/manage/customers/#{@order.customer.reference}"}
            >
              {@order.customer.full_name}
            </.link>
          </:item>

          <:item title="Total">
            {format_money(@settings.currency, @order.total_cost)}
          </:item>

          <:item title="Fecha de entrega">
            {format_date(@order.delivery_date, @time_zone)}
          </:item>

          <:item title="Descripción">
            {@order.description || "—"}
          </:item>

          <:item title="Creado el">
            {format_date(@order.inserted_at, @time_zone)}
          </:item>
        </.list>
      </.tabs_content>

      <.tabs_content :if={@live_action == :items}>
        <.table id="order-items" rows={@order.items}>
          <:col :let={item} label="Producto">
            <.link
              class="hover:text-blue-800 hover:underline"
              navigate={~p"/manage/products/#{item.product.id}"}
            >
              <div class="flex items-center space-x-2">
                <img
                  :if={item.product.featured_photo != nil}
                  src={
                    CraftplanWeb.PhotoUrl.signed(
                      Photo,
                      :thumb,
                      {item.product.featured_photo, item.product}
                    )
                  }
                  alt={item.product.name}
                  class="h-5 w-5"
                />
                <span>
                  {item.product.name}
                </span>
              </div>
            </.link>
          </:col>
          <:col :let={item} label="Cantidad">{item.quantity}</:col>
          <:col :let={item} label="Precio unitario">
            {format_money(@settings.currency, item.product.price)}
          </:col>
          <:col :let={item} label="Total">
            {format_money(@settings.currency, item.cost)}
          </:col>
          <:col :let={item} label="Estado">
            <.badge
              text={order_item_status_label(item.status)}
              colors={[
                {:todo, "#{order_item_status_bg(:todo)} #{order_item_status_color(:todo)}"},
                {:in_progress,
                 "#{order_item_status_bg(:in_progress)} #{order_item_status_color(:in_progress)}"},
                {:done, "#{order_item_status_bg(:done)} #{order_item_status_color(:done)}"}
              ]}
            />
          </:col>
          <:action :let={item}>
            <button
              type="button"
              phx-click="update_item_status"
              phx-value-item_id={item.id}
              title={if item.status == :done, do: "Marcar como pendiente", else: "Marcar como listo"}
              class="inline-flex items-center gap-2"
            >
              <span class={[
                "relative inline-flex h-5 w-9 shrink-0 items-center rounded-full transition",
                item.status == :done && "bg-emerald-500",
                item.status != :done && "bg-stone-300"
              ]}>
                <span class={[
                  "inline-block h-4 w-4 transform rounded-full bg-white shadow transition",
                  item.status == :done && "translate-x-4",
                  item.status != :done && "translate-x-0.5"
                ]} />
              </span>
            </button>
          </:action>
        </.table>
      </.tabs_content>
    </div>

    <.modal
      :if={@pending_consumption_item_id}
      id="consume-confirm-modal"
      show
      title="Confirmar consumo de materiales"
      on_cancel={JS.push("cancel_consume")}
    >
      <p class="mb-3 text-sm text-stone-700">
        Completar este artículo consumirá materiales según la lista de materiales (BOM) del producto. Revisa las cantidades y confirma.
      </p>
      <.table id="order-consumption-recap" rows={@pending_consumption_recap}>
        <:col :let={row} label="Material">{row.material.name}</:col>
        <:col :let={row} label="Requerido">{format_amount(row.material.unit, row.required)}</:col>
        <:col :let={row} label="Stock actual">
          {format_amount(row.material.unit, row.current_stock || Decimal.new(0))}
        </:col>
      </.table>
      <footer>
        <.button variant={:outline} phx-click="cancel_consume">Cerrar</.button>
        <.button variant={:primary} phx-click="confirm_consume">Consumir ahora</.button>
      </footer>
    </.modal>

    <.modal
      :if={@live_action == :edit}
      id="order-modal"
      show
      title={@page_title}
      max_width="max-w-xl"
      on_cancel={JS.patch(~p"/manage/orders/#{@order.reference}")}
    >
      <.live_component
        module={CraftplanWeb.OrderLive.FormComponent}
        id={(@order && @order.id) || :new}
        current_user={@current_user}
        title={@page_title}
        action={@live_action}
        order={@order}
        products={@products}
        customers={@customers}
        settings={@settings}
        patch={~p"/manage/orders/#{@order.reference}"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    products =
      Catalog.list_products!(actor: socket.assigns[:current_user])

    customers =
      CRM.list_customers!(actor: socket.assigns[:current_user], load: [:full_name])

    {:ok,
     assign(socket,
       products: products,
       customers: customers,
       pending_consumption_item_id: nil,
       pending_consumption_recap: []
     )}
  end

  @impl true
  def handle_params(%{"reference" => reference}, _, socket) do
    order =
      Orders.get_order_by_reference!(reference,
        load: @default_order_load,
        actor: socket.assigns[:current_user]
      )

    live_action = socket.assigns.live_action

    tabs_links = [
      %{
        label: "Detalles",
        navigate: ~p"/manage/orders/#{order.reference}/details",
        active: live_action in [:details, :show]
      },
      %{
        label: "Artículos",
        navigate: ~p"/manage/orders/#{order.reference}/items",
        active: live_action == :items
      }
    ]

    socket =
      socket
      |> assign(:page_title, page_title(live_action))
      |> assign(:order, order)
      |> assign(:tabs_links, tabs_links)

    {:noreply, Navigation.assign(socket, :orders, order_trail(order, live_action))}
  end

  @impl true
  def handle_event("update_item_status", %{"item_id" => item_id}, socket) do
    actor = socket.assigns.current_user
    item = Enum.find(socket.assigns.order.items, &(&1.id == item_id))

    next_status =
      case item.status do
        :done -> :todo
        _ -> :done
      end

    case Orders.update_item(item, %{status: next_status}, actor: actor) do
      {:ok, _item} ->
        order =
          Orders.get_order_by_id!(socket.assigns.order.id,
            load: @default_order_load,
            actor: actor
          )

        {:noreply, assign(socket, :order, order)}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, "No se pudo actualizar el estado: #{Exception.message(error)}")}
    end
  end

  @impl true
  def handle_event("confirm_consume", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("cancel_consume", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("change_status", %{"new_status" => new_status}, socket) do
    status_atom = String.to_existing_atom(new_status)

    case Orders.update_order_status(
           socket.assigns.order,
           %{status: status_atom},
           actor: socket.assigns.current_user
         ) do
      {:ok, order} ->
        {:noreply,
         socket
         |> put_flash(:info, "Estado actualizado a #{order_status_label(status_atom)}")
         |> assign(:order, order)}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, "No se pudo actualizar el estado: #{Exception.message(error)}")}
    end
  end

  @impl true
  def handle_info({CraftplanWeb.OrderLive.FormComponentItems, {:saved, _}}, socket) do
    order =
      Orders.get_order_by_id!(socket.assigns.order.id,
        load: @default_order_load,
        actor: socket.assigns[:current_user]
      )

    {:noreply,
     socket
     |> put_flash(:info, "Artículos del pedido actualizados correctamente")
     |> assign(:order, order)
     |> push_event("close-modal", %{id: "order-item-modal"})}
  end

  @impl true
  def handle_info({CraftplanWeb.OrderLive.FormComponent, {:saved, _}}, socket) do
    order =
      Orders.get_order_by_id!(socket.assigns.order.id,
        load: @default_order_load,
        actor: socket.assigns[:current_user]
      )

    {:noreply,
     socket
     |> put_flash(:info, "Pedido actualizado correctamente")
     |> assign(:order, order)
     |> assign(
       :customers,
       CRM.list_customers!(actor: socket.assigns[:current_user], load: [:full_name])
     )}
  end

  defp page_title(:show), do: "Ver pedido"
  defp page_title(:edit), do: "Editar pedido"
  defp page_title(:details), do: "Detalles del pedido"
  defp page_title(:items), do: "Artículos del pedido"

  defp order_trail(order, :items) do
    [
      Navigation.root(:orders),
      Navigation.resource(:order, order),
      Navigation.page(:orders, :order_items, order)
    ]
  end

  defp order_trail(order, _), do: [Navigation.root(:orders), Navigation.resource(:order, order)]
end
