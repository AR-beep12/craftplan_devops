defmodule CraftplanWeb.PurchasingLive.Show do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias Craftplan.Inventory
  alias Craftplan.Inventory.Receiving
  alias CraftplanWeb.Navigation

  @impl true
  def render(assigns) do
    assigns =
      assign_new(assigns, :breadcrumbs, fn -> [] end)

    ~H"""
    <.header>
      {@po.reference}
      <:actions>
        <.link patch={~p"/manage/purchasing/#{@po.reference}/add_item"}>
          <.button variant={:outline}>Agregar artículo</.button>
        </.link>

        <.link :if={@po.status != :received} phx-click={JS.push("receive", value: %{id: @po.id})}>
          <.button variant={:primary}>Marcar como recibido</.button>
        </.link>
      </:actions>
    </.header>
    <.sub_nav links={@tabs_links} />
    <div class="mt-4 space-y-4">
      <.tabs_content :if={@live_action in [:show]}>
        <.list>
          <:item title="Referencia">
            <.kbd>{@po.reference}</.kbd>
          </:item>

          <:item title="Proveedor">{@po.supplier.name}</:item>

          <:item title="Estado">{po_status_label(@po.status)}</:item>

          <:item title="Fecha de pedido">{format_time(@po.ordered_at, @time_zone)}</:item>

          <:item title="Fecha de recepción">{format_time(@po.received_at, @time_zone)}</:item>
        </.list>
      </.tabs_content>

      <.tabs_content :if={@live_action not in [:show]}>
        <div>
          <.table id="po-items" rows={@po.items}>
            <:col :let={i} label="Material">{i.material.name}</:col>

            <:col :let={i} label="Cantidad">{format_amount(i.material.unit, i.quantity)}</:col>

            <:col :let={i} label="Precio unitario">
              {format_money(@settings.currency, i.unit_price || Decimal.new(0))}
            </:col>
          </.table>
        </div>
      </.tabs_content>
    </div>

    <.modal
      :if={@live_action == :add_item}
      id="po-item-modal"
      show
      title={"Agregar artículo a #{@po.reference}"}
      on_cancel={
        JS.patch(
          if @live_action in [:items, :add_item],
            do: ~p"/manage/purchasing/#{@po.reference}/items",
            else: ~p"/manage/purchasing/#{@po.reference}"
        )
      }
    >
      <.live_component
        module={CraftplanWeb.PurchasingLive.PurchaseOrderItemFormComponent}
        id="po-item-form"
        current_user={@current_user}
        materials={@materials}
        po_id={@po.id}
        purchase_order_item={nil}
        patch={
          if @live_action in [:items, :add_item],
            do: ~p"/manage/purchasing/#{@po.reference}/items",
            else: ~p"/manage/purchasing/#{@po.reference}"
        }
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    materials = Inventory.list_materials!(actor: socket.assigns[:current_user])
    {:ok, assign(socket, materials: materials, purchasing_tab: :purchase_orders)}
  end

  @impl true
  def handle_params(%{"po_ref" => ref}, _uri, socket) do
    opts = [actor: socket.assigns[:current_user], load: [:supplier, items: [material: [:unit]]]]

    case Inventory.get_purchase_order_by_reference(ref, opts) do
      {:ok, nil} ->
        {:noreply,
         socket
         |> put_flash(:error, "Orden de compra no encontrada")
         |> push_navigate(to: ~p"/manage/purchasing")}

      {:ok, po} ->
        live_action = socket.assigns.live_action

        tabs_links = [
          %{
            label: "Resumen",
            navigate: ~p"/manage/purchasing/#{po.reference}",
            active: live_action == :show
          },
          %{
            label: "Artículos",
            navigate: ~p"/manage/purchasing/#{po.reference}/items",
            active: live_action in [:items, :add_item]
          }
        ]

        socket =
          socket
          |> assign(:po, po)
          |> assign(:tabs_links, tabs_links)

        {:noreply, Navigation.assign(socket, :purchasing, po_trail(po, live_action))}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "No se pudo cargar la orden de compra")
         |> push_navigate(to: ~p"/manage/purchasing")}
    end
  end

  @impl true
  def handle_event("receive", %{"id" => id}, socket) do
    _ = Receiving.receive_po(id, actor: socket.assigns.current_user)
    {:noreply, push_navigate(socket, to: ~p"/manage/purchasing/#{socket.assigns.po.reference}")}
  end

  @impl true
  def handle_info({:po_item_saved, _item}, socket) do
    po =
      Inventory.get_purchase_order_by_reference!(socket.assigns.po.reference,
        actor: socket.assigns[:current_user],
        load: [:supplier, items: [material: [:unit]]]
      )

    {:noreply,
     socket
     |> assign(:po, po)
     |> put_flash(:info, "Artículo agregado a la orden de compra")
     |> push_event("close-modal", %{id: "po-item-modal"})}
  end

  defp po_trail(po, :items) do
    [
      Navigation.root(:purchasing),
      Navigation.page(:purchasing, :purchase_orders),
      Navigation.resource(:purchase_order, po),
      Navigation.page(:purchasing, :po_items, po)
    ]
  end

  defp po_trail(po, :add_item) do
    [
      Navigation.root(:purchasing),
      Navigation.page(:purchasing, :purchase_orders),
      Navigation.resource(:purchase_order, po),
      Navigation.page(:purchasing, :po_add_item, po)
    ]
  end

  defp po_trail(po, _),
    do: [
      Navigation.root(:purchasing),
      Navigation.page(:purchasing, :purchase_orders),
      Navigation.resource(:purchase_order, po)
    ]

  defp po_status_label(:draft), do: "Borrador"
  defp po_status_label(:ordered), do: "Pedido"
  defp po_status_label(:received), do: "Recibido"

  defp po_status_label(status) when is_binary(status), do: status |> String.to_existing_atom() |> po_status_label()

  defp po_status_label(status), do: to_string(status)
end
