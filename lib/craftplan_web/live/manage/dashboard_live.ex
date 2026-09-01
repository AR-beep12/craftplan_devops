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

    out_of_stock_materials = load_out_of_stock_materials(actor)

    socket =
      socket
      |> assign(:page_title, "Dashboard")
      |> assign(:upcoming_orders, pending_page.results)
      |> assign(:pending_orders_count, pending_page.count)
      |> assign(:out_of_stock_materials, Enum.take(out_of_stock_materials, 5))
      |> assign(:out_of_stock_count, length(out_of_stock_materials))

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
        <div class="flex items-center gap-4 rounded-lg border border-stone-200 bg-white p-4 shadow-xs transition-all duration-200 hover:-translate-y-0.5 hover:border-primary-200 hover:shadow-md">
          <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-md bg-primary-50 text-primary-600">
            <.icon name="hero-shopping-bag-solid" class="h-5 w-5" />
          </div>
          <div>
            <p class="text-xs font-medium uppercase tracking-wide text-stone-500">
              Pedidos pendientes
            </p>
            <p class="text-2xl font-semibold text-stone-900">{@pending_orders_count}</p>
          </div>
        </div>
        <div class="flex items-center gap-4 rounded-lg border border-stone-200 bg-white p-4 shadow-xs transition-all duration-200 hover:-translate-y-0.5 hover:border-primary-200 hover:shadow-md">
          <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-md bg-primary-50 text-primary-600">
            <.icon name="hero-archive-box-solid" class="h-5 w-5" />
          </div>
          <div>
            <p class="text-xs font-medium uppercase tracking-wide text-stone-500">
              Materiales sin stock
            </p>
            <p class="text-2xl font-semibold text-stone-900">{@out_of_stock_count}</p>
          </div>
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
                <h3 class="text-sm font-semibold text-stone-900">Sin stock</h3>
                <p class="text-xs text-stone-500">Materiales que necesitás reponer.</p>
              </div>
            </:header>
            <.table
              id="dashboard-out-of-stock"
              rows={@out_of_stock_materials}
              variant={:compact}
              zebra
              no_margin
              row_click={fn row -> JS.navigate("/manage/inventory/#{row.id}") end}
            >
              <:col :let={row} label="Material">{row.name}</:col>
              <:col :let={row} label="Actual" align={:right}>
                {format_amount(row.unit, row.current_stock)}
              </:col>
              <:empty>
                <div class="rounded-md border border-dashed border-stone-200 bg-stone-50 py-6 text-center text-sm text-stone-500">
                  Todos los materiales tienen stock disponible.
                </div>
              </:empty>
            </.table>
          </Page.surface>
        </Page.form_grid>
      </Page.section>
    </Page.page>
    """
  end

  defp load_out_of_stock_materials(actor) do
    actor
    |> then(&Inventory.list_materials!(actor: &1, load: [:current_stock]))
    |> Enum.filter(fn material ->
      is_nil(material.current_stock) or Decimal.compare(material.current_stock, Decimal.new(0)) != :gt
    end)
    |> Enum.sort_by(& &1.name)
  end
end
