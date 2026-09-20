defmodule CraftplanWeb.ProductionBatchLive.Index do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias Craftplan.Catalog
  alias Craftplan.Production
  alias CraftplanWeb.Components.Page
  alias CraftplanWeb.Navigation

  @default_filters %{
    "status" => ["open", "in_progress"],
    "product_name" => ""
  }

  @impl true
  def mount(_params, _session, socket) do
    products = Catalog.list_products!(actor: socket.assigns[:current_user])

    {:ok,
     socket
     |> assign(:batches, [])
     |> assign(:filters, @default_filters)
     |> assign(:products, products)
     |> assign(:page_title, "Lotes")}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, load_batches(socket)}
  end

  defp load_batches(socket) do
    actor = socket.assigns[:current_user]
    filters = parse_filters(socket.assigns.filters)

    batches = Production.list_batches(filters, actor: actor)

    socket
    |> assign(:batches, batches)
    |> Navigation.assign(:production, [
      Navigation.root(:production),
      Navigation.page(:production, :batches)
    ])
  end

  defp parse_filters(filters) do
    %{
      status: parse_list(filters["status"]),
      product_name: filters["product_name"]
    }
  end

  defp parse_list([]), do: nil
  defp parse_list(nil), do: nil
  defp parse_list(list) when is_list(list), do: list
  defp parse_list(value), do: [value]

  @impl true
  def render(assigns) do
    assigns =
      assign_new(assigns, :breadcrumbs, fn -> [] end)

    ~H"""
    <Page.page>
      <.header>
        Lotes de producción
        <:subtitle>
          Todos los lotes de producción con estado e información de costos.
        </:subtitle>
      </.header>

      <Page.surface>
        <:header>
          <div class="space-y-1">
            <h2 class="text-sm font-semibold text-stone-900">Filtrar lotes</h2>

            <p class="text-sm text-stone-500">
              Reduce la lista por estado o producto.
            </p>
          </div>
        </:header>

        <:actions>
          <Page.filter_reset />
        </:actions>

        <form id="filters-form" phx-change="apply_filters">
          <Page.form_grid columns={2} class="max-w-full">
            <div class="min-w-[12rem]">
              <.input
                label="Estado"
                type="checkdrop"
                name="filters[status][]"
                id="status"
                value={@filters["status"]}
                multiple={true}
                options={[
                  {"Abierto", "open"},
                  {"En progreso", "in_progress"},
                  {"Completado", "completed"},
                  {"Cancelado", "canceled"}
                ]}
              />
            </div>

            <.input
              type="select"
              name="filters[product_name]"
              id="product_name"
              value={@filters["product_name"]}
              label="Producto"
              options={[{"Todos los productos", ""} | Enum.map(@products, &{&1.name, &1.name})]}
            />
          </Page.form_grid>
        </form>
      </Page.surface>

      <Page.section class="mt-6">
        <Page.surface>
          <.table id="batches-table" rows={@batches}>
            <:empty>
              <div class="rounded border border-dashed border-stone-200 bg-stone-50 py-8 text-center text-sm text-stone-500">
                Ningún lote coincide con los filtros actuales.
              </div>
            </:empty>

            <:col :let={batch} label="Lote">
              <.link navigate={~p"/manage/production/batches/#{batch.batch_code}"}>
                <.kbd>{batch.batch_code}</.kbd>
              </.link>
            </:col>

            <:col :let={batch} label="Producto">
              {(batch.product && batch.product.name) || "—"}
            </:col>

            <:col :let={batch} label="Estado">
              <.badge
                text={batch_status_text(batch.status)}
                value={batch.status}
                colors={[
                  open: "bg-blue-50 text-blue-700 border-blue-200",
                  in_progress: "bg-amber-50 text-amber-700 border-amber-200",
                  completed: "bg-green-50 text-green-700 border-green-200",
                  canceled: "bg-stone-50 text-stone-500 border-stone-200"
                ]}
              />
            </:col>

            <:col :let={batch} label="Cant. planificada">
              {Decimal.to_string(batch.planned_qty)}
            </:col>

            <:col :let={batch} label="Cant. producida">
              {if batch.status == :completed, do: Decimal.to_string(batch.produced_qty), else: "—"}
            </:col>

            <:col :let={batch} label="Creado">
              {format_time(batch.inserted_at, @time_zone)}
            </:col>

            <:action :let={batch}>
              <.link navigate={~p"/manage/production/batches/#{batch.batch_code}"}>
                <.button size={:sm} variant={:outline}>Ver</.button>
              </.link>
            </:action>
          </.table>
        </Page.surface>
      </Page.section>
    </Page.page>
    """
  end

  @impl true
  def handle_event("apply_filters", %{"filters" => raw_filters}, socket) do
    new_filters = Map.merge(socket.assigns.filters, raw_filters)
    {:noreply, socket |> assign(:filters, new_filters) |> load_batches()}
  end

  @impl true
  def handle_event("reset_filters", _params, socket) do
    {:noreply, socket |> assign(:filters, @default_filters) |> load_batches()}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply, load_batches(socket)}
  end

  # Spanish display label for a production batch status.
  defp batch_status_text(:open), do: "Abierto"
  defp batch_status_text(:in_progress), do: "En progreso"
  defp batch_status_text(:completed), do: "Completado"
  defp batch_status_text(:canceled), do: "Cancelado"
  defp batch_status_text(status), do: to_string(status)
end
