defmodule CraftplanWeb.InventoryLive.Show do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias Craftplan.Inventory
  alias CraftplanWeb.Navigation

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:tabs_links, fn -> [] end)
      |> assign_new(:breadcrumbs, fn -> [] end)

    ~H"""
    <.header>
      {@material.name}
      <:actions>
        <.link patch={~p"/manage/inventory/#{@material.id}/edit"} phx-click={JS.push_focus()}>
          <.button>Editar</.button>
        </.link>

        <.link patch={~p"/manage/inventory/#{@material.id}/adjust"} phx-click={JS.push_focus()}>
          <.button variant={:primary}>Ajustar stock</.button>
        </.link>
      </:actions>
    </.header>
    <.sub_nav links={@tabs_links} />
    <div class="mt-4 space-y-6">
      <.tabs_content :if={@live_action in [:details, :show]}>
        <.list>
          <:item title="Nombre">{@material.name}</:item>

          <:item title="Color">
            {@material.color || "—"}
          </:item>

          <:item title="Descripción">
            {@material.extra_description || "—"}
          </:item>

          <:item title="Cantidad">
            {format_quantity(@material.current_stock)}
          </:item>
        </.list>

        <div :if={!Enum.empty?(@open_po_items)} class="mt-6">
          <div class="mb-2 text-base font-medium text-stone-900">Órdenes de compra abiertas</div>

          <.table id="material-open-pos" rows={@open_po_items}>
            <:col :let={poi} label="Orden de compra">
              <.link navigate={~p"/manage/purchasing/#{poi.purchase_order.reference}"}>
                <.kbd>{poi.purchase_order.reference}</.kbd>
              </.link>
            </:col>

            <:col :let={poi} label="Proveedor">
              <.link navigate={~p"/manage/purchasing/suppliers"} class="hover:underline">
                {poi.purchase_order.supplier.name}
              </.link>
            </:col>

            <:col :let={poi} label="Cantidad">
              {format_amount(@material.unit, poi.quantity)}
            </:col>

            <:col :let={poi} label="Estado">{po_status_label(poi.purchase_order.status)}</:col>
          </.table>
        </div>
      </.tabs_content>
      <%!-- Alérgenos y Nutrición desactivados temporalmente --%>
      <%!--
      <.tabs_content :if={@live_action == :allergens}>
        <.live_component
          module={CraftplanWeb.InventoryLive.FormComponentAllergens}
          id="material-allergens-form"
          material={@material}
          current_user={@current_user}
          settings={@settings}
          patch={~p"/manage/inventory/#{@material.id}/allergens"}
          allergens={@allergens_available}
        />
      </.tabs_content>

      <.tabs_content :if={@live_action == :nutritional_facts}>
        <.live_component
          module={CraftplanWeb.InventoryLive.FormComponentNutritionalFacts}
          id="material-nutritional-facts-form"
          material={@material}
          current_user={@current_user}
          settings={@settings}
          patch={~p"/manage/inventory/#{@material.id}/nutritional_facts"}
          nutritional_facts={@nutritional_facts_available}
        />
      </.tabs_content>
      --%>
      <.tabs_content :if={@live_action == :stock}>
        <div>
          <.table id="inventory_movements" no_margin rows={@material.movements}>
            <:empty>
              <div class="block py-4 pr-6">
                <span class={["relative"]}>
                  No se encontraron movimientos
                </span>
              </div>
            </:empty>

            <:col :let={entry} label="Fecha">
              {format_time(entry.inserted_at, @time_zone)}
            </:col>

            <:col :let={entry} label="Cantidad">
              {format_amount(@material.unit, entry.quantity)}
            </:col>

            <:col :let={entry} label="Motivo">{entry.reason}</:col>
          </.table>
        </div>
      </.tabs_content>
    </div>

    <.modal
      :if={@live_action == :edit}
      id="material-modal"
      title={@page_title}
      show
      on_cancel={JS.patch(~p"/manage/inventory/#{@material.id}")}
    >
      <.live_component
        module={CraftplanWeb.InventoryLive.FormComponentMaterial}
        id={@material.id}
        title={@page_title}
        action={@live_action}
        current_user={@current_user}
        material={@material}
        settings={@settings}
        patch={~p"/manage/inventory/#{@material.id}/details"}
      />
    </.modal>

    <.modal
      :if={@live_action == :adjust}
      title={"Ajustar stock de #{@material.name}"}
      id="material-movement-modal"
      show
      on_cancel={JS.patch(~p"/manage/inventory/#{@material.id}")}
    >
      <.live_component
        module={CraftplanWeb.InventoryLive.FormComponentMovement}
        id={@material.id}
        material={@material}
        current_user={@current_user}
        settings={@settings}
        patch={~p"/manage/inventory/#{@material.id}/stock"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       :allergens_available,
       Inventory.list_allergens!(actor: socket.assigns[:current_user])
     )
     |> assign(
       :nutritional_facts_available,
       Inventory.list_nutritional_facts!(actor: socket.assigns[:current_user])
     )}
  end

  @impl true
  def handle_params(params, _, socket) do
    id = params["id"] || params["sku"]
    material = fetch_material(id, socket.assigns[:current_user])

    open_po_items =
      Inventory.list_open_po_items_for_material!(
        %{material_id: material.id},
        actor: socket.assigns[:current_user]
      )

    live_action = socket.assigns.live_action

    tabs_links = [
      %{
        label: "Detalles",
        navigate: ~p"/manage/inventory/#{material.id}/details",
        active: live_action in [:details, :show]
      },
      # Alérgenos y Nutrición desactivados - descomenta para reactivar
      # %{
      #   label: "Alérgenos",
      #   navigate: ~p"/manage/inventory/#{material.id}/allergens",
      #   active: live_action == :allergens
      # },
      # %{
      #   label: "Nutrición",
      #   navigate: ~p"/manage/inventory/#{material.id}/nutritional_facts",
      #   active: live_action == :nutritional_facts
      # },
      %{
        label: "Stock",
        navigate: ~p"/manage/inventory/#{material.id}/stock",
        active: live_action == :stock
      }
    ]

    socket =
      socket
      |> assign(:page_title, page_title(live_action))
      |> assign(:material, material)
      |> assign(:open_po_items, open_po_items)
      |> assign(:tabs_links, tabs_links)

    {:noreply, Navigation.assign(socket, :inventory, material_trail(material, live_action))}
  end

  # helper functions removed; calls now pass actor explicitly in mount

  @impl true
  def handle_info({:saved_nutritional_facts, material_id}, socket) do
    material =
      Inventory.get_material_by_id!(material_id,
        actor: socket.assigns[:current_user],
        load: [
          :current_stock,
          :movements,
          :allergens,
          :material_allergens,
          :nutritional_facts,
          material_nutritional_facts: [:nutritional_fact]
        ]
      )

    {:noreply, assign(socket, :material, material)}
  end

  @impl true
  def handle_info({:saved_allergens, material_id}, socket) do
    material =
      Inventory.get_material_by_id!(material_id,
        actor: socket.assigns[:current_user],
        load: [
          :current_stock,
          :movements,
          :allergens,
          :material_allergens,
          :nutritional_facts,
          material_nutritional_facts: [:nutritional_fact]
        ]
      )

    {:noreply, assign(socket, :material, material)}
  end

  @impl true
  def handle_info({:saved, %Inventory.Movement{material_id: material_id}}, socket) do
    material =
      Inventory.get_material_by_id!(material_id,
        actor: socket.assigns[:current_user],
        load: [
          :current_stock,
          :movements,
          :allergens,
          :material_allergens,
          :nutritional_facts,
          material_nutritional_facts: [:nutritional_fact]
        ]
      )

    {:noreply, assign(socket, :material, material)}
  end

  @impl true
  def handle_info({:saved, %Inventory.Material{id: material_id}}, socket) do
    material =
      Inventory.get_material_by_id!(material_id,
        actor: socket.assigns[:current_user],
        load: [
          :current_stock,
          :movements,
          :allergens,
          :material_allergens,
          :nutritional_facts,
          material_nutritional_facts: [:nutritional_fact]
        ]
      )

    {:noreply, assign(socket, :material, material)}
  end

  defp page_title(:show), do: "Ver material"
  defp page_title(:adjust), do: "Ajustar material"
  defp page_title(:edit), do: "Editar material"
  defp page_title(:details), do: "Detalles del material"
  defp page_title(:allergens), do: "Alérgenos del material"
  defp page_title(:nutritional_facts), do: "Nutrición del material"
  defp page_title(:stock), do: "Stock del material"

  defp po_status_label(:draft), do: "Borrador"
  defp po_status_label(:ordered), do: "Pedido"
  defp po_status_label(:received), do: "Recibido"

  defp po_status_label(status) when is_binary(status), do: status |> String.to_existing_atom() |> po_status_label()

  defp po_status_label(status), do: to_string(status)

  defp material_trail(material, :allergens) do
    [
      Navigation.root(:inventory),
      Navigation.resource(:material, material),
      Navigation.page(:inventory, :material_allergens, material)
    ]
  end

  defp material_trail(material, :nutritional_facts) do
    [
      Navigation.root(:inventory),
      Navigation.resource(:material, material),
      Navigation.page(:inventory, :material_nutrition, material)
    ]
  end

  defp material_trail(material, :stock) do
    [
      Navigation.root(:inventory),
      Navigation.resource(:material, material),
      Navigation.page(:inventory, :material_stock, material)
    ]
  end

  defp material_trail(material, _), do: [Navigation.root(:inventory), Navigation.resource(:material, material)]

  defp fetch_material(id, actor) do
    Inventory.get_material_by_id!(id,
      actor: actor,
      load: [
        :current_stock,
        :movements,
        :allergens,
        :material_allergens,
        :nutritional_facts,
        material_nutritional_facts: [:nutritional_fact]
      ]
    )
  end

  defp format_quantity(nil), do: "0"

  defp format_quantity(%Decimal{} = qty), do: qty |> Decimal.normalize() |> Decimal.to_string(:normal)

  defp format_quantity(qty) when is_number(qty), do: to_string(qty)
  defp format_quantity(qty), do: to_string(qty)
end
