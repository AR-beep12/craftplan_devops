defmodule CraftplanWeb.InventoryLive.Index do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias Craftplan.Inventory
  alias Craftplan.InventoryForecasting
  alias Craftplan.Orders
  alias CraftplanWeb.Components.Page
  alias CraftplanWeb.Navigation

  @impl true
  def render(assigns) do
    first_forecast_day =
      assigns
      |> Map.get(:days_range)
      |> case do
        nil -> nil
        [] -> nil
        days -> List.first(days)
      end

    assigns =
      assigns
      |> assign_new(:nav_sub_links, fn -> [] end)
      |> assign_new(:breadcrumbs, fn -> [] end)
      |> assign(:first_forecast_day, first_forecast_day)

    ~H"""
    <Page.page>
      <.header>
        Inventario
        <:actions :if={@live_action in [:index, :forecast]}>
          <.link patch={~p"/manage/inventory/new"}>
            <.button variant={:primary}>Nuevo material</.button>
          </.link>
        </:actions>
      </.header>

      <Page.surface>
        <.table
          id="materials"
          rows={@streams.materials}
          row_id={fn {dom_id, _} -> dom_id end}
          row_click={fn {_, material} -> JS.navigate(~p"/manage/inventory/#{material.id}") end}
        >
          <:col :let={{_, material}} label="">
            <span
              :if={out_of_stock?(material.current_stock)}
              class="inline-flex items-center justify-center"
              title="Out of stock"
            >
              <.icon name="hero-exclamation-triangle" class="h-5 w-5 text-rose-500" />
            </span>
          </:col>

          <:col :let={{_, material}} label="Material">{material.name}</:col>

          <:col :let={{_, material}} label="ID">
            <.kbd>{String.slice(material.id, 0, 8)}</.kbd>
          </:col>

          <:col :let={{_, material}} label="Color">
            {material.color || "—"}
          </:col>

          <:col :let={{_, material}} label="Cantidad">
            {format_quantity(material.current_stock)}
          </:col>

          <:col :let={{_, material}} label="Descripción">
            <span class="max-w-[20ch] block truncate" title={material.extra_description}>
              {material.extra_description || "—"}
            </span>
          </:col>

          <:action :let={{_, material}}>
            <div class="sr-only">
              <.link navigate={~p"/manage/inventory/#{material.id}"}>Ver</.link>
            </div>
          </:action>

          <:action :let={{_, material}}>
            <.link
              phx-click={JS.push("delete", value: %{id: material.id}) |> hide("##{material.id}")}
              data-confirm="¿Estás seguro?"
            >
              <.button size={:sm} variant={:danger}>
                Eliminar
              </.button>
            </.link>
          </:action>
        </.table>

        <div
          :if={@materials_empty?}
          class="rounded-md border border-dashed border-stone-200 bg-stone-50 py-10 text-center text-sm text-stone-500"
        >
          No se encontraron materiales. Agrega tu primer ingrediente para comenzar a registrar el stock.
        </div>
      </Page.surface>

      <Page.section :if={@live_action == :forecast}>
        <Page.surface padding="p-5">
          <:header>
            <div>
              <h3 class="text-sm font-semibold text-stone-900">
                Cómo leer el pronóstico de uso
              </h3>

              <p class="text-xs text-stone-500">
                Estos consejos te ayudan a interpretar las etiquetas de requerimiento y la columna de balance final.
              </p>
            </div>
          </:header>

          <div class="space-y-4 text-sm text-stone-600">
            <div>
              <p class="text-sm font-semibold text-stone-700">Necesidad vs. balance proyectado</p>

              <p class="text-xs text-stone-500">
                Cada etiqueta muestra el balance restante después del requerimiento de ese día. Haz clic en una
                etiqueta para ver los pedidos/productos que generan la demanda.
              </p>
            </div>

            <div class="space-y-3">
              <p class="text-sm font-semibold text-stone-700">Estados de color</p>

              <div class="space-y-2 text-xs text-stone-500">
                <div class="flex items-start gap-3">
                  <span class="mt-1 h-3 w-3 rounded-full bg-emerald-200 ring-2 ring-emerald-300" />
                  <div>
                    <p class="font-medium text-stone-700">Equilibrado</p>

                    <p>
                      El balance proyectado se mantiene por encima del requerimiento; no se necesita ninguna acción.
                    </p>
                  </div>
                </div>

                <div class="flex items-start gap-3">
                  <span class="mt-1 h-3 w-3 rounded-full bg-amber-200 ring-2 ring-amber-300" />
                  <div>
                    <p class="font-medium text-stone-700">Atención</p>

                    <p>
                      El requerimiento consume todo el balance. Confirma el momento de reabastecimiento.
                    </p>
                  </div>
                </div>

                <div class="flex items-start gap-3">
                  <span class="mt-1 h-3 w-3 rounded-full bg-rose-200 ring-2 ring-rose-300" />
                  <div>
                    <p class="font-medium text-rose-600">Escasez</p>

                    <p>
                      El requerimiento excede el stock disponible. Inicia una transferencia u orden de compra.
                    </p>
                  </div>
                </div>
              </div>
            </div>

            <div>
              <p class="text-sm font-semibold text-stone-700">Columna de balance final</p>

              <p class="text-xs text-stone-500">
                La última columna suma el requerimiento total de cada material en la ventana actual para que
                puedas compararlo rápidamente con el inventario disponible.
              </p>
            </div>
          </div>
        </Page.surface>
      </Page.section>

      <Page.section :if={@live_action == :forecast}>
        <div class="space-y-4">
          <div id="controls">
            <Page.surface>
              <:header>
                <div>
                  <h3 class="text-sm font-semibold text-stone-900">
                    Pronóstico de uso
                  </h3>

                  <p class="text-xs text-stone-500">
                    Requerimientos de materiales día a día frente al stock para el horizonte seleccionado.
                  </p>
                </div>
              </:header>

              <:actions>
                <div class="flex items-center overflow-hidden rounded-md border border-stone-300">
                  <button
                    type="button"
                    phx-click="today"
                    class="flex items-center gap-2 border-r border-stone-300 bg-white px-3 py-1 text-xs font-medium tracking-wide text-stone-600 transition hover:bg-stone-50"
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="h-4 w-4"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
                      />
                    </svg>
                    Hoy
                  </button>

                  <button
                    type="button"
                    phx-click="next_week"
                    class="flex items-center gap-2 bg-white px-3 py-1 text-xs font-medium tracking-wide text-stone-600 transition hover:bg-stone-50"
                  >
                    Próximos 7 días
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="h-4 w-4"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M13 7l5 5m0 0l-5 5m5-5H6"
                      />
                    </svg>
                  </button>
                </div>
              </:actions>
            </Page.surface>
          </div>

          <Page.surface full_bleed padding="p-0">
            <.scroll_table
              id="usage-forecast-table"
              min_width="w-[1300px]"
              aria_label="Cuadrícula de pronóstico de uso"
            >
              <table class="w-full table-fixed border-collapse text-sm">
                <thead class="bg-stone-50 text-left text-xs font-semibold tracking-wide text-stone-500">
                  <tr>
                    <th class="sticky left-0 z-20 w-48 border-r border-stone-200 bg-white p-3 text-left">
                      Material
                    </th>

                    <th
                      :for={{day, _index} <- Enum.with_index(@days_range)}
                      class={
                        [
                          "w-1/5 border-r border-stone-200 p-3 font-normal last:border-r-0",
                          is_today?(day) && "bg-indigo-50"
                        ]
                        |> Enum.reject(&is_nil/1)
                      }
                    >
                      <div class="flex items-center justify-center">
                        <div class={[
                          "inline-flex items-center justify-center space-x-1 rounded px-2",
                          is_today?(day) && "bg-indigo-500 text-white"
                        ]}>
                          <div>{format_day_name(day)}</div>

                          <div>{format_short_date(day, @time_zone)}</div>
                        </div>
                      </div>
                    </th>

                    <th class="w-1/5 border-stone-200 p-3 text-left font-normal">
                      Balance final
                    </th>
                  </tr>
                </thead>

                <tbody class="text-stone-700">
                  <tr
                    :for={{material, material_data} <- @materials_requirements}
                    class="border-t border-stone-200"
                  >
                    <td class="sticky left-0 z-10 border-r border-stone-200 bg-white px-3 py-2 text-left font-medium shadow-sm">
                      {material.name}
                    </td>

                    <td
                      :for={
                        {
                          {day_quantity, day},
                          index
                        } <- Enum.with_index(material_data.quantities)
                      }
                      class="relative border-t border-r border-t-stone-200 border-r-stone-200 p-3 text-left align-top"
                    >
                      <% day_balance = Enum.at(material_data.balance_cells, index) %> <% status =
                        forecast_status(day_quantity, day_balance) %>
                      <div class="group relative mt-3 inline-flex">
                        <button
                          type="button"
                          phx-click="view_material_details"
                          phx-value-date={Date.to_iso8601(day)}
                          phx-value-material={material.id}
                          class={[
                            "inline-flex w-full items-center gap-1 px-2 py-0.5 text-xs font-medium transition focus-visible:ring-primary-400 focus-visible:outline-none focus-visible:ring-2",
                            forecast_status_chip(status)
                          ]}
                        >
                          <div class="grid-row-2 grid">
                            <div class="grid-row-2 grid">
                              <div>{format_amount(material.unit, day_balance)}</div>
                            </div>
                          </div>
                        </button>

                        <div class={[
                          "min-w-[11rem] max-w-[14rem] text-[11px] pointer-events-none absolute top-0 left-0 z-10 z-30 hidden -translate-y-full flex-col gap-1 rounded-md border bg-white p-3 shadow-lg ring-1 group-focus-within:flex group-hover:flex",
                          forecast_popover_class(status)
                        ]}>
                          <p class="text-stone-600">
                            Balance proyectado
                            <span class="font-bold">
                              {format_amount(material.unit, day_balance)}
                            </span>
                          </p>

                          <p class="text-stone-600">
                            Requerido
                            <span class="font-bold">
                              {format_amount(material.unit, day_quantity)}
                            </span>
                          </p>
                          <hr class="text-stone-300" />
                          <p class={[forecast_popover_label_class(status)]}>
                            {popover_label(status, material.unit, day_quantity, day_balance)}
                          </p>
                        </div>
                      </div>
                    </td>

                    <td class={[
                      "border-t border-t-stone-200 p-2 text-right",
                      forecast_status_chip(
                        if Decimal.gt?(0, material_data.final_balance),
                          do: :shortage,
                          else: :balanced
                      )
                    ]}>
                      {format_amount(material.unit, material_data.final_balance)}
                    </td>
                  </tr>
                </tbody>
              </table>
            </.scroll_table>
          </Page.surface>
        </div>
      </Page.section>

      <.modal
        :if={@live_action in [:new, :edit]}
        id="material-modal"
        title={@page_title}
        description="Usa este formulario para gestionar los registros de materiales en tu base de datos."
        show
        on_cancel={JS.patch(~p"/manage/inventory")}
      >
        <.live_component
          module={CraftplanWeb.InventoryLive.FormComponentMaterial}
          id={(@material && @material.id) || :new}
          current_user={@current_user}
          title={@page_title}
          action={@live_action}
          material={@material}
          settings={@settings}
          patch={~p"/manage/inventory"}
        />
      </.modal>

      <.modal
        :if={@selected_material_date && @selected_material}
        id="material-details-modal"
        title={
        "#{@selected_material.name} para #{format_day_name(@selected_material_date)} #{format_short_date(@selected_material_date, @time_zone)}"
        }
        show
        on_cancel={JS.push("close_material_modal")}
      >
        <div class="py-4">
          <div :if={@material_details && !Enum.empty?(@material_details)} class="space-y-4">
            <.table id="material-products" rows={@material_details}>
              <:col :let={{_product, items}} label="Referencias de pedidos">
                <div class="grid grid-cols-1 gap-1 text-sm">
                  <div :for={item <- items.order_items}>
                    <.link navigate={~p"/manage/orders/#{item.order.reference}"}>
                      <.kbd>
                        {format_reference(item.order.reference)}
                      </.kbd>
                    </.link>
                  </div>
                </div>
              </:col>

              <:col :let={{product, _items}} label="Producto">
                <div class="font-medium">{product.name}</div>
              </:col>

              <:col :let={{_product, items}} label="Total requerido">
                <div class="text-sm">
                  {format_amount(@selected_material.unit, items.total_quantity)}
                </div>
              </:col>

              <:empty>
                <div class="rounded-md border border-dashed border-stone-200 bg-stone-50 py-6 text-center text-sm text-stone-500">
                  No se encontraron detalles de producto para este material
                </div>
              </:empty>
            </.table>
          </div>

          <div
            :if={!@material_details || Enum.empty?(@material_details)}
            class="rounded-md border border-dashed border-stone-200 bg-stone-50 py-8 text-center text-sm text-stone-500"
          >
            No se encontraron detalles para este material en esta fecha
          </div>
        </div>

        <footer class="mt-6 flex items-center justify-end gap-3">
          <.button variant={:outline} phx-click="close_material_modal">Cerrar</.button>
          <.link
            patch={~p"/manage/inventory/#{@selected_material.id}/adjust"}
            phx-click={JS.push_focus()}
          >
            <.button variant={:primary}>Ajustar stock</.button>
          </.link>
        </footer>
      </.modal>
    </Page.page>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    today = Date.utc_today()
    days_range = date_range(today)

    materials_requirements = prepare_materials_requirements(socket, days_range)

    socket =
      socket
      |> assign(:today, today)
      |> assign(:days_range, days_range)
      |> assign(:materials_requirements, materials_requirements)
      |> assign(:selected_material_date, nil)
      |> assign(:selected_material, nil)
      |> assign(:material_details, nil)
      |> assign(:material_day_quantity, nil)
      |> assign(:material_day_balance, nil)
      |> assign(:materials_empty?, true)
      |> stream(:materials, [])

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    live_action = socket.assigns.live_action

    socket = apply_action(socket, live_action, params)

    {:noreply, Navigation.assign(socket, :inventory, inventory_trail(socket.assigns))}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Nuevo material")
    |> assign(:material, nil)
  end

  defp apply_action(socket, :index, _params) do
    # Reload materials when returning to index
    materials =
      [actor: socket.assigns[:current_user], stream?: true, load: [:current_stock]]
      |> Inventory.list_materials!()
      |> Enum.to_list()

    socket
    |> stream(:materials, materials, reset: true)
    |> assign(:page_title, "Inventario")
    |> assign(:material, nil)
    |> assign(:materials_empty?, Enum.empty?(materials))
  end

  defp apply_action(socket, :forecast, _params) do
    today = Date.utc_today()
    days_range = date_range(today)
    materials_requirements = prepare_materials_requirements(socket, days_range)

    socket
    |> assign(:page_title, "Pronóstico de uso")
    |> assign(:material, nil)
    |> assign(:today, today)
    |> assign(:days_range, days_range)
    |> assign(:materials_requirements, materials_requirements)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    material =
      Inventory.get_material_by_id!(id,
        load: [:current_stock],
        actor: socket.assigns[:current_user]
      )

    socket
    |> assign(:page_title, "Editar material")
    |> assign(:material, material)
  end

  @impl true
  def handle_event("view_material_details", %{"date" => date_str, "material" => material_id}, socket) do
    date = Date.from_iso8601!(date_str)
    material = Inventory.get_material_by_id!(material_id, actor: socket.assigns.current_user)

    # Get material day quantity
    {day_quantity, day_balance} =
      InventoryForecasting.get_material_day_info(
        material,
        date,
        socket.assigns.materials_requirements
      )

    # Get details of orders/products using this material on this day
    start_time = DateTime.new!(date, ~T[00:00:00], socket.assigns.time_zone)
    end_time = DateTime.new!(date, ~T[23:59:59], socket.assigns.time_zone)

    orders =
      Orders.list_orders!(
        %{delivery_date_start: start_time, delivery_date_end: end_time},
        actor: socket.assigns.current_user,
        load: [
          :reference,
          items: [
            :quantity,
            product: [:name, active_bom: [:rollup]]
          ]
        ]
      )

    details =
      InventoryForecasting.get_material_usage_details(
        material,
        orders,
        socket.assigns.current_user
      )

    {:noreply,
     socket
     |> assign(:selected_material_date, date)
     |> assign(:selected_material, material)
     |> assign(:material_details, details)
     |> assign(:material_day_quantity, day_quantity)
     |> assign(:material_day_balance, day_balance)}
  end

  @impl true
  def handle_event("close_material_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_material_date, nil)
     |> assign(:selected_material, nil)
     |> assign(:material_details, nil)
     |> assign(:material_day_quantity, nil)
     |> assign(:material_day_balance, nil)}
  end

  @impl true
  def handle_event("next_week", _params, socket) do
    # Move the date range forward by 7 days
    new_start = Date.add(List.first(socket.assigns.days_range), 7)
    days_range = date_range(new_start)

    materials_requirements = prepare_materials_requirements(socket, days_range)

    {:noreply,
     socket
     |> assign(:days_range, days_range)
     |> assign(:materials_requirements, materials_requirements)}
  end

  @impl true
  def handle_event("today", _params, socket) do
    # Reset to current day and forward
    today = Date.utc_today()
    days_range = date_range(today)

    materials_requirements = prepare_materials_requirements(socket, days_range)

    {:noreply,
     socket
     |> assign(:today, today)
     |> assign(:days_range, days_range)
     |> assign(:materials_requirements, materials_requirements)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    material =
      Inventory.get_material_by_id!(id,
        actor: socket.assigns.current_user,
        load: [:current_stock, :movements, :material_allergens, :material_nutritional_facts]
      )

    # Bloquear eliminación si aún tiene stock
    if material.current_stock && Decimal.compare(material.current_stock, Decimal.new(0)) != :eq do
      {:noreply,
       put_flash(
         socket,
         :error,
         "No se puede eliminar: aún tiene stock (#{format_quantity(material.current_stock)}). Ajusta a 0 con Ajustar stock primero."
       )}
    else
      # Limpiar relaciones que bloquean FK (movimientos, alérgenos, nutrición) antes de borrar
      Enum.each(material.movements, fn m ->
        Ash.destroy(m, actor: socket.assigns.current_user)
      end)

      Enum.each(material.material_allergens, fn ma ->
        Ash.destroy(ma, actor: socket.assigns.current_user)
      end)

      Enum.each(material.material_nutritional_facts, fn mf ->
        Ash.destroy(mf, actor: socket.assigns.current_user)
      end)

      case Inventory.destroy_material(material, actor: socket.assigns.current_user) do
        :ok ->
          socket = stream_delete(socket, :materials, %{id: id})

          remaining =
            [actor: socket.assigns.current_user, load: [:current_stock]]
            |> Inventory.list_materials!()
            |> Enum.to_list()

          {:noreply,
           socket
           |> put_flash(:info, "Material eliminado correctamente")
           |> assign(:materials_empty?, Enum.empty?(remaining))}

        {:error, error} ->
          # Si aún falla (ej. usado en BOMs o pedidos), mostrar detalle
          msg =
            case error do
              %{errors: [%{message: msg} | _]} when is_binary(msg) -> msg
              _ -> "No se pudo eliminar: está usado en recetas o pedidos."
            end

          {:noreply, put_flash(socket, :error, msg)}
      end
    end
  end

  @impl true
  def handle_info({:saved, material}, socket) do
    material = Ash.load!(material, :current_stock, actor: socket.assigns.current_user)

    {:noreply,
     socket
     |> stream_insert(:materials, material)
     |> assign(:materials_empty?, false)}
  end

  defp forecast_status(day_quantity, balance) do
    cond do
      Decimal.compare(day_quantity, Decimal.new(0)) != :gt -> :none
      Decimal.compare(balance, day_quantity) == :lt -> :shortage
      Decimal.compare(balance, day_quantity) == :eq -> :watch
      Decimal.compare(balance, Decimal.new(0)) == :eq -> :watch
      true -> :balanced
    end
  end

  defp forecast_popover_class(:shortage), do: "border-rose-200 ring-rose-100"
  defp forecast_popover_class(:watch), do: "border-amber-200 ring-amber-100"
  defp forecast_popover_class(:balanced), do: "border-emerald-200 ring-emerald-100"
  defp forecast_popover_class(_), do: "border-stone-200 ring-stone-200"

  defp forecast_popover_label_class(:shortage), do: "text-rose-600"
  defp forecast_popover_label_class(:watch), do: "text-amber-600"
  defp forecast_popover_label_class(:balanced), do: "text-emerald-600"
  defp forecast_popover_label_class(_), do: "text-stone-600"

  defp forecast_status_chip(:shortage), do: "border border-rose-300 bg-rose-50 text-rose-700"
  defp forecast_status_chip(:watch), do: "border border-amber-300 bg-amber-50 text-amber-700"

  defp forecast_status_chip(:balanced), do: "border border-emerald-300 bg-emerald-50 text-emerald-700"

  defp forecast_status_chip(_), do: "border border-stone-200 bg-stone-50 text-stone-500"

  defp popover_label(:shortage, unit, required, balance) do
    shortfall = Decimal.max(Decimal.sub(required, balance), Decimal.new(0))
    "Escasez de #{format_amount(unit, shortfall)}"
  end

  defp popover_label(:watch, _unit, _required, _balance), do: "Consume todo el balance"

  defp popover_label(:balanced, unit, required, balance) do
    remaining = Decimal.sub(balance, required)
    "Deja #{format_amount(unit, remaining)} disponible"
  end

  defp popover_label(_status, unit, _required, balance) do
    "Balance #{format_amount(unit, balance)}"
  end

  defp inventory_trail(%{live_action: :new}),
    do: [Navigation.root(:inventory), Navigation.page(:inventory, :new_material)]

  defp inventory_trail(%{live_action: :forecast}),
    do: [Navigation.root(:inventory), Navigation.page(:inventory, :forecast)]

  defp inventory_trail(%{live_action: :edit, material: material}) when not is_nil(material),
    do: [Navigation.root(:inventory), Navigation.resource(:material, material)]

  defp inventory_trail(_assigns), do: [Navigation.root(:inventory)]

  defp prepare_materials_requirements(socket, days_range) do
    InventoryForecasting.prepare_materials_requirements(days_range, socket.assigns.current_user)
  end

  defp out_of_stock?(nil), do: true
  defp out_of_stock?(%Decimal{} = qty), do: Decimal.compare(qty, Decimal.new(0)) == :eq
  defp out_of_stock?(qty) when is_number(qty), do: qty == 0
  defp out_of_stock?(_), do: false

  defp format_quantity(nil), do: "0"

  defp format_quantity(%Decimal{} = qty), do: qty |> Decimal.normalize() |> Decimal.to_string(:normal)

  defp format_quantity(qty) when is_number(qty), do: to_string(qty)
  defp format_quantity(qty), do: to_string(qty)
end
