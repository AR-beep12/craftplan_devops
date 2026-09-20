defmodule CraftplanWeb.CustomerLive.Index do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias CraftplanWeb.Components.Page
  alias CraftplanWeb.Navigation

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Clientes
      <:subtitle>Gestiona los registros de tus clientes</:subtitle>
      <:actions>
        <.link patch={~p"/manage/customers/new"}>
          <.button variant={:primary}>Nuevo cliente</.button>
        </.link>
      </:actions>
    </.header>

    <Page.surface>
      <.table
        id="customers"
        rows={@streams.customers}
        row_click={fn {_id, customer} -> JS.navigate(~p"/manage/customers/#{customer.reference}") end}
      >
        <:col :let={{_id, customer}} label="Nombre">{customer.full_name}</:col>
        <:col :let={{_id, customer}} label="ID">
          <.kbd>
            {format_reference(customer.reference)}
          </.kbd>
        </:col>
        <:col :let={{_id, customer}} label="Correo electrónico">{customer.email}</:col>
        <:col :let={{_id, customer}} label="Teléfono">{customer.phone}</:col>
      </.table>
      <div
        :if={@customers_empty?}
        class="rounded-md border border-dashed border-stone-200 bg-stone-50 py-10 text-center text-sm text-stone-500"
      >
        No se encontraron clientes
      </div>
    </Page.surface>

    <.modal
      :if={@live_action in [:new, :edit]}
      id="customer-modal"
      title={@page_title}
      description="Usa este formulario para gestionar los registros de clientes en tu base de datos."
      show
      on_cancel={JS.patch(~p"/manage/customers")}
    >
      <.live_component
        module={CraftplanWeb.CustomerLive.FormComponent}
        id={(@customer && @customer.id) || :new}
        current_user={@current_user}
        title={@page_title}
        action={@live_action}
        customer={@customer}
        settings={@settings}
        patch={~p"/manage/customers"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    customers =
      [actor: socket.assigns[:current_user], load: [:full_name]]
      |> Craftplan.CRM.list_customers!()
      |> Enum.to_list()

    {:ok,
     socket
     |> stream(:customers, customers)
     |> assign(:customers_empty?, Enum.empty?(customers))
     |> assign_new(:current_user, fn -> nil end)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket = apply_action(socket, socket.assigns.live_action, params)

    {:noreply, Navigation.assign(socket, :customers, customer_index_trail(socket.assigns))}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Editar cliente")
    |> assign(
      :customer,
      Craftplan.CRM.get_customer_by_id!(id, actor: socket.assigns.current_user)
    )
  end

  defp apply_action(socket, :edit, %{"reference" => reference}) do
    socket
    |> assign(:page_title, "Editar cliente")
    |> assign(
      :customer,
      Craftplan.CRM.get_customer_by_reference!(reference, actor: socket.assigns.current_user)
    )
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Nuevo cliente")
    |> assign(:customer, nil)
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Clientes")
    |> assign(:customer, nil)
  end

  defp customer_index_trail(%{live_action: :new}),
    do: [Navigation.root(:customers), Navigation.page(:customers, :new_customer)]

  defp customer_index_trail(%{live_action: :edit, customer: %{} = customer}),
    do: [Navigation.root(:customers), Navigation.resource(:customer, customer)]

  defp customer_index_trail(_), do: [Navigation.root(:customers)]

  @impl true
  def handle_info({CraftplanWeb.CustomerLive.FormComponent, {:saved, customer}}, socket) do
    customer = Ash.load!(customer, [:full_name], actor: socket.assigns.current_user)
    {:noreply, socket |> stream_insert(:customers, customer) |> assign(:customers_empty?, false)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    case id
         |> Craftplan.CRM.get_customer_by_id!(actor: socket.assigns.current_user)
         |> Craftplan.CRM.destroy_customer(actor: socket.assigns.current_user) do
      :ok ->
        socket = stream_delete(socket, :customers, %{id: id})

        remaining =
          [actor: socket.assigns.current_user, load: [:full_name]]
          |> Craftplan.CRM.list_customers!()
          |> Enum.to_list()

        {:noreply,
         socket
         |> put_flash(:info, "Cliente eliminado correctamente")
         |> assign(:customers_empty?, Enum.empty?(remaining))}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "No se pudo eliminar el cliente.")}
    end
  end
end
