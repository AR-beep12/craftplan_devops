defmodule CraftplanWeb.ProductLive.Index do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias Craftplan.Catalog
  alias Craftplan.Catalog.Product.Photo

  @impl true
  def render(assigns) do
    assigns =
      assign_new(assigns, :breadcrumbs, fn -> [] end)

    ~H"""
    <.header>
      Productos
      <:actions>
        <.link patch={~p"/manage/products/new"}>
          <.button variant={:primary}>Nuevo producto</.button>
        </.link>
      </:actions>
    </.header>

    <.table
      id="products"
      rows={@streams.products}
      row_click={fn {_, product} -> JS.navigate(~p"/manage/products/#{product.id}") end}
      row_id={fn {dom_id, _} -> dom_id end}
    >
      <:col :let={{_, product}} label="Nombre">
        <div class="flex items-center space-x-2">
          <img
            :if={product.featured_photo != nil}
            src={Photo.url({product.featured_photo, product}, :thumb, signed: true)}
            alt={product.name}
            class="h-5 w-5"
          />
          <span>
            {product.name}
          </span>
        </div>
      </:col>
      <:col :let={{_, product}} label="Categoría">
        {product.category && product.category.name || "-"}
      </:col>
      <:col :let={{_, product}} label="Precio">
        {format_money(@settings.currency, product.price)}
      </:col>

      <:action :let={{_, product}}>
        <.link
          phx-click={JS.push("delete", value: %{id: product.id}) |> hide("#product-#{product.id}")}
          data-confirm="¿Estás seguro de que deseas eliminar este producto? Esta acción no se puede deshacer."
        >
          <.button size={:sm} variant={:danger}>
            Eliminar
          </.button>
        </.link>
      </:action>
    </.table>

    <div :if={@products_count == 0} class="py-8 text-center text-sm text-stone-500">
      No se encontraron productos
    </div>

    <.modal
      :if={@live_action in [:new, :edit]}
      id="product-modal"
      show
      title={@page_title}
      on_cancel={JS.patch(~p"/manage/products")}
    >
      <.live_component
        module={CraftplanWeb.ProductLive.FormComponent}
        id={(@product && @product.id) || :new}
        title={@page_title}
        action={@live_action}
        product={@product}
        current_user={@current_user}
        settings={@settings}
        patch={~p"/manage/products"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    products =
      Catalog.list_products!(
        actor: socket.assigns[:current_user],
        page: [limit: 100],
        load: [
          :materials_cost,
          :bom_unit_cost,
          :markup_percentage,
          :gross_profit,
          :category
        ]
      )

    results =
      case products do
        %Ash.Page.Keyset{results: res} -> res
        %Ash.Page.Offset{results: res} -> res
        other -> other
      end

    socket =
      socket
      |> assign(:breadcrumbs, [
        %{label: "Productos", path: ~p"/manage/products", current?: true}
      ])
      |> assign(:products_count, length(results))
      |> assign(:product_ids, MapSet.new(Enum.map(results, & &1.id)))
      |> stream(:products, results)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Nuevo producto")
    |> assign(:product, nil)
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Catálogo")
    |> assign(:product, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    product =
      Catalog.get_product_by_id!(id, actor: socket.assigns.current_user, load: [:category])

    alias Craftplan.Repo
    import Ecto.Query

    bom_ids =
      case Catalog.list_boms_for_product(%{product_id: product.id},
             actor: socket.assigns.current_user,
             authorize?: false
           ) do
        {:ok, boms} -> Enum.map(boms, & &1.id)
        _ -> []
      end

    if bom_ids != [] do
      Repo.delete_all(from c in Craftplan.Catalog.BOMComponent, where: c.bom_id in ^bom_ids)
      Repo.delete_all(from r in Craftplan.Catalog.BOMRollup, where: r.bom_id in ^bom_ids)
      Repo.delete_all(from l in Craftplan.Catalog.LaborStep, where: l.bom_id in ^bom_ids)
      Repo.delete_all(from b in Craftplan.Catalog.BOM, where: b.id in ^bom_ids)
    end

    case Catalog.destroy_product(product, actor: socket.assigns.current_user) do
      :ok ->
        new_ids = MapSet.delete(socket.assigns.product_ids, id)

        {:noreply,
         socket
         |> put_flash(:info, "Producto eliminado correctamente")
         |> assign(:product_ids, new_ids)
         |> assign(:products_count, MapSet.size(new_ids))
         |> stream_delete(:products, %{id: id})}

      {:error, error} ->
        require Logger
        Logger.error("Failed to delete product #{id}: #{inspect(error)}")

        {:noreply,
         put_flash(socket, :error, "No se pudo eliminar el producto: #{inspect(error)}")}
    end
  end

  @impl true
  def handle_info({CraftplanWeb.ProductLive.FormComponent, {:saved, product}}, socket) do
    product =
      Ash.load!(
        product,
        [:materials_cost, :bom_unit_cost, :markup_percentage, :gross_profit, :category],
        actor: socket.assigns.current_user
      )

    new_ids = MapSet.put(socket.assigns.product_ids, product.id)

    {:noreply,
     socket
     |> assign(:product_ids, new_ids)
     |> assign(:products_count, MapSet.size(new_ids))
     |> stream_insert(:products, product)}
  end
end
