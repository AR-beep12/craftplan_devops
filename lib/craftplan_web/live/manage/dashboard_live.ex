defmodule CraftplanWeb.DashboardLive do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias Craftplan.Inventory
  alias Craftplan.Orders
  alias CraftplanWeb.Components.Page
  alias Phoenix.LiveView.JS

  @pending_statuses [:unconfirmed, :confirmed, :in_progress, :ready]

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns[:current_user]

    pending_page =
      Orders.list_orders!(%{status: @pending_statuses},
        actor: actor,
        page: [limit: 5, count: true],
        load: [customer: [:full_name]]
      )

    low_stock_materials = load_low_stock_materials(actor)

    socket =
      socket
      |> assign(:page_title, "Dashboard")
      |> assign(:upcoming_orders, pending_page.results)
      |> assign(:pending_orders_count, pending_page.count)
      |> assign(:low_stock_materials, Enum.take(low_stock_materials, 5))
      |> assign(:low_stock_count, length(low_stock_materials))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:nav_sub_links, fn -> [] end)
      |> assign_new(:breadcrumbs, fn -> [] end)

    ~H"""
    <Page.page>
      <.header>
        Dashboard
        <:subtitle>
          Un vistazo rápido a lo que necesita tu atención hoy.
        </:subtitle>
      </.header>

      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <div class="rounded-lg border border-stone-200 bg-white p-4">
          <p class="text-xs font-medium uppercase tracking-wide text-stone-500">
            Pedidos pendientes
          </p>
          <p class="mt-1 text-2xl font-semibold text-stone-900">{@pending_orders_count}</p>
        </div>
        <div class="rounded-lg border border-stone-200 bg-white p-4">
          <p class="text-xs font-medium uppercase tracking-wide text-stone-500">
            Materiales con stock bajo
          </p>
          <p class="mt-1 text-2xl font-semibold text-stone-900">{@low_stock_count}</p>
        </div>
      </div>

      <Page.section>
        <Page.form_grid columns={2}>
          <Page.surface>
            <:header>
              <div>
                <h3 class="text-sm font-semibold text-stone-900">Próximos pedidos</h3>
                <p class="text-xs text-stone-500">Los que están por confirmarse o entregarse.</p>
              </div>
            </:header>
            <.table
              id="dashboard-upcoming-orders"
              rows={@upcoming_orders}
              variant={:compact}
              zebra
              no_margin
              row_click={fn row -> JS.navigate("/manage/orders/#{row.reference}") end}
            >
              <:col :let={row} label="Referencia">
                <.kbd>{row.reference}</.kbd>
              </:col>
              <:col :let={row} label="Cliente">{row.customer.full_name}</:col>
              <:col :let={row} label="Entrega">{format_date(row.delivery_date)}</:col>
              <:col :let={row} label="Total" align={:right}>
                {format_money(@settings.currency, row.total)}
              </:col>
              <:empty>
                <div class="rounded-md border border-dashed border-stone-200 bg-stone-50 py-6 text-center text-sm text-stone-500">
                  No hay pedidos pendientes en este momento.
                </div>
              </:empty>
            </.table>
          </Page.surface>

          <Page.surface>
            <:header>
              <div>
                <h3 class="text-sm font-semibold text-stone-900">Stock bajo</h3>
                <p class="text-xs text-stone-500">Materiales en o por debajo de su mínimo.</p>
              </div>
            </:header>
            <.table
              id="dashboard-low-stock"
              rows={@low_stock_materials}
              variant={:compact}
              zebra
              no_margin
              row_click={fn row -> JS.navigate("/manage/inventory/#{row.sku}") end}
            >
              <:col :let={row} label="Material">{row.name}</:col>
              <:col :let={row} label="Actual" align={:right}>
                {format_amount(row.unit, row.current_stock)}
              </:col>
              <:col :let={row} label="Mínimo" align={:right}>
                {format_amount(row.unit, row.minimum_stock)}
              </:col>
              <:empty>
                <div class="rounded-md border border-dashed border-stone-200 bg-stone-50 py-6 text-center text-sm text-stone-500">
                  Todos los materiales están en buen nivel.
                </div>
              </:empty>
            </.table>
          </Page.surface>
        </Page.form_grid>
      </Page.section>
    </Page.page>
    """
  end

  defp load_low_stock_materials(actor) do
    actor
    |> then(&Inventory.list_materials!(actor: &1, load: [:current_stock]))
    |> Enum.filter(fn material ->
      not is_nil(material.minimum_stock) and
        Decimal.compare(material.current_stock, material.minimum_stock) != :gt
    end)
    |> Enum.sort_by(& &1.name)
  end
end
