defmodule CraftplanWeb.PurchasingLive.Suppliers do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias Craftplan.Inventory
  alias CraftplanWeb.Navigation

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:nav_sub_links, fn -> [] end)
      |> assign_new(:breadcrumbs, fn -> [] end)

    ~H"""
    <.header>
      Proveedores
      <:actions>
        <.link patch={~p"/manage/purchasing/suppliers/new"}>
          <.button variant={:primary}>Nuevo proveedor</.button>
        </.link>
      </:actions>
    </.header>

    <div class="mt-4">
      <.table
        id="suppliers"
        rows={@suppliers}
        row_click={fn sup -> JS.patch(~p"/manage/purchasing/suppliers/#{sup.id}/edit") end}
      >
        <:col :let={s} label="Nombre">{s.name}</:col>

        <:col :let={s} label="Contacto">{s.contact_name}</:col>

        <:col :let={s} label="Correo electrónico">{s.contact_email}</:col>

        <:col :let={s} label="Teléfono">{s.contact_phone}</:col>

        <:action :let={s}>
          <.link patch={~p"/manage/purchasing/suppliers/#{s.id}/edit"}>
            <.button size={:sm} variant={:outline}>Editar</.button>
          </.link>
        </:action>
      </.table>
    </div>

    <.modal
      :if={@live_action in [:new, :edit]}
      id="supplier-modal"
      show
      title={if @live_action == :new, do: "Nuevo proveedor", else: "Editar proveedor"}
      on_cancel={JS.patch(~p"/manage/purchasing/suppliers")}
    >
      <.live_component
        module={CraftplanWeb.PurchasingLive.SupplierFormComponent}
        id={(@supplier && @supplier.id) || :new}
        current_user={@current_user}
        supplier={@supplier}
        patch={~p"/manage/purchasing/suppliers"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    suppliers = Inventory.list_suppliers!(actor: socket.assigns[:current_user])

    {:ok, assign(socket, suppliers: suppliers, supplier: nil, purchasing_tab: :suppliers)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket = assign(socket, :page_title, "Proveedores")

    socket =
      case socket.assigns.live_action do
        :edit ->
          sup = Inventory.get_supplier_by_id!(params["id"], actor: socket.assigns.current_user)
          assign(socket, :supplier, sup)

        :new ->
          assign(socket, :supplier, nil)

        _ ->
          assign(socket, :supplier, nil)
      end

    {:noreply, Navigation.assign(socket, :purchasing, suppliers_trail(socket.assigns))}
  end

  @impl true
  def handle_info({:supplier_saved, _sup}, socket) do
    {:noreply,
     socket
     |> assign(:suppliers, Inventory.list_suppliers!(actor: socket.assigns.current_user))
     |> put_flash(:info, "Proveedor guardado")
     |> push_event("close-modal", %{id: "supplier-modal"})}
  end

  defp suppliers_trail(%{live_action: :new}) do
    [
      Navigation.root(:purchasing),
      Navigation.page(:purchasing, :suppliers),
      Navigation.page(:purchasing, :new_supplier)
    ]
  end

  defp suppliers_trail(%{live_action: :edit, supplier: %{} = supplier}) do
    [
      Navigation.root(:purchasing),
      Navigation.page(:purchasing, :suppliers),
      Navigation.resource(:supplier, supplier)
    ]
  end

  defp suppliers_trail(_), do: [Navigation.root(:purchasing), Navigation.page(:purchasing, :suppliers)]
end
