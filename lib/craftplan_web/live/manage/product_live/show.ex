defmodule CraftplanWeb.ProductLive.Show do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias Craftplan.Catalog
  alias Craftplan.Inventory

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:nav_sub_links, fn -> [] end)
      |> assign_new(:breadcrumbs, fn -> [] end)

    ~H"""
    <.header>
      {@product.name}
      <:actions>
        <.link patch={~p"/manage/products/#{@product.id}/edit"} phx-click={JS.push_focus()}>
          <.button variant={:primary}>Editar producto</.button>
        </.link>
      </:actions>
    </.header>

    <.sub_nav links={@tabs_links} />

    <div class="mt-6 space-y-6">
      <.tabs_content :if={@live_action in [:details, :show]}>
        <.list>
          <:item title="Categoría">
            {(@product.category && @product.category.name) || "-"}
          </:item>
          <:item title="Disponibilidad">
            <.badge text={selling_availability_label(@product.selling_availability)} />
          </:item>
          <:item title="Nombre">{@product.name}</:item>
          <:item title="Precio">
            {format_money(@settings.currency, @product.price)}
          </:item>
        </.list>
        <div class="mt-8 border-t border-stone-200 pt-6">
          <.live_component
            module={CraftplanWeb.ProductLive.FormComponentRecipe}
            id="material-form-detalles"
            product={@product}
            current_user={@current_user}
            settings={@settings}
            materials={@materials_available}
            products={@products_available}
            selected_version={@selected_bom_version}
            patch={~p"/manage/products/#{@product.id}/details"}
            on_cancel={hide_modal("product-material-modal")}
            compact={true}
          />
        </div>
      </.tabs_content>

      <.tabs_content :if={@live_action == :photos}>
        <.live_component
          module={CraftplanWeb.ProductLive.FormComponentPhotos}
          id={@product.id}
          title={@page_title}
          action={@live_action}
          current_user={@current_user}
          product={@product}
          settings={@settings}
          patch={~p"/manage/products/#{@product.id}"}
        />
      </.tabs_content>
    </div>

    <.modal
      :if={@live_action == :edit}
      id="product-modal"
      title={@page_title}
      description="Actualiza la información y los detalles del producto."
      show
      on_cancel={JS.patch(~p"/manage/products/#{@product.id}")}
    >
      <.live_component
        module={CraftplanWeb.ProductLive.FormComponent}
        id={@product.id}
        title={@page_title}
        action={@live_action}
        current_user={@current_user}
        product={@product}
        settings={@settings}
        patch={~p"/manage/products/#{@product.id}/details"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       materials_available: list_available_materials(),
       products_available: list_available_products()
     )}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _, socket) do
    product =
      Catalog.get_product_by_id!(id,
        load: [
          :markup_percentage,
          :gross_profit,
          :materials_cost,
          :allergens,
          :nutritional_facts,
          :bom_unit_cost,
          :category,
          active_bom: [:rollup, components: [:material, :product], labor_steps: []]
        ]
      )

    live_action = socket.assigns.live_action

    selected_bom_version =
      case Map.get(params, "v") do
        v when is_binary(v) ->
          case Integer.parse(v) do
            {ver, _} -> ver
            _ -> nil
          end

        _ ->
          nil
      end

    tabs_links = [
      %{
        label: "Detalles",
        navigate: ~p"/manage/products/#{product.id}/details",
        active: live_action in [:details, :show]
      },
      %{
        label: "Fotos",
        navigate: ~p"/manage/products/#{product.id}/photos",
        active: live_action == :photos
      }
    ]

    socket =
      socket
      |> assign(:page_title, page_title(live_action))
      |> assign(:product, product)
      |> assign(:selected_bom_version, selected_bom_version)
      |> assign(:tabs_links, tabs_links)
      |> assign(:breadcrumbs, product_breadcrumbs(product, live_action))

    {:noreply, socket}
  end

  @impl true
  def handle_info({CraftplanWeb.ProductLive.FormComponentPhotos, {:saved, _}}, socket) do
    product =
      Catalog.get_product_by_id!(socket.assigns.product.id,
        load: [
          :markup_percentage,
          :materials_cost,
          :gross_profit,
          :nutritional_facts,
          :bom_unit_cost,
          :category,
          active_bom: [components: [:material, :product], labor_steps: []]
        ]
      )

    {:noreply,
     socket
     |> put_flash(:info, "Fotos actualizadas correctamente")
     |> assign(:product, product)}
  end

  @impl true
  def handle_info({CraftplanWeb.ProductLive.FormComponentRecipe, {:saved, _}}, socket) do
    product =
      Catalog.get_product_by_id!(socket.assigns.product.id,
        load: [
          :markup_percentage,
          :materials_cost,
          :gross_profit,
          :nutritional_facts,
          :allergens,
          :bom_unit_cost,
          :category,
          active_bom: [components: [:material, :product], labor_steps: []]
        ],
        actor: socket.assigns.current_user
      )

    {:noreply,
     socket
     |> put_flash(:info, "Material guardado exitosamente")
     |> assign(:product, product)
     |> push_event("close-modal", %{id: "product-material-modal"})}
  end

  def handle_info({CraftplanWeb.ProductLive.FormComponent, {:saved, _}}, socket) do
    product =
      Catalog.get_product_by_id!(socket.assigns.product.id,
        load: [
          :markup_percentage,
          :materials_cost,
          :gross_profit,
          :nutritional_facts,
          :allergens,
          :bom_unit_cost,
          :category
        ],
        actor: socket.assigns.current_user
      )

    {:noreply,
     socket
     |> put_flash(:info, "Producto actualizado correctamente")
     |> assign(:product, product)}
  end

  defp page_title(:show), do: "Producto"
  defp page_title(:nutrition), do: "Información nutricional del producto"
  defp page_title(:edit), do: "Modificar producto"
  defp page_title(:recipe), do: "Receta del producto"
  defp page_title(:details), do: "Producto"
  defp page_title(_), do: "Producto"

  defp product_breadcrumbs(product, live_action) do
    base = [
      %{label: "Productos", path: ~p"/manage/products", current?: false},
      %{
        label: product.name,
        path: ~p"/manage/products/#{product.id}",
        current?: live_action in [:show, :details]
      }
    ]

    case live_action do
      :recipe ->
        base ++
          [
            %{label: "Receta", path: ~p"/manage/products/#{product.id}/recipe", current?: true}
          ]

      :nutrition ->
        base ++
          [
            %{
              label: "Nutrición",
              path: ~p"/manage/products/#{product.id}/nutrition",
              current?: true
            }
          ]

      :photos ->
        base ++
          [
            %{label: "Fotos", path: ~p"/manage/products/#{product.id}/photos", current?: true}
          ]

      _ ->
        List.update_at(base, 1, &Map.put(&1, :current?, true))
    end
  end

  defp list_available_materials do
    Inventory.list_materials!()
  end

  defp list_available_products do
    Catalog.list_products!(load: [:bom_unit_cost])
  end

  defp nutrition_heading(facts) do
    if nutrition_declaration?(facts), do: "Declaración nutricional", else: "Datos nutricionales"
  end

  defp nutrition_amount_label(facts) do
    if nutrition_declaration?(facts) do
      "Por #{nutrition_basis_label(facts)}"
    else
      "Cantidad"
    end
  end

  defp nutrition_basis_label(facts) do
    facts
    |> Enum.find(&Map.get(&1, :declaration?, false))
    |> case do
      %{per_quantity: quantity, per_unit: unit} ->
        "#{format_basis_quantity(quantity)} #{basis_unit_abbreviation(unit)}"

      _ ->
        "100 g"
    end
  end

  defp nutrition_declaration?(facts), do: Enum.any?(facts, &Map.get(&1, :declaration?, false))

  defp nutrient_label(%{parent_key: parent_key, name: name}) when not is_nil(parent_key) do
    "de los cuales #{String.downcase(name)}"
  end

  defp nutrient_label(%{name: name}), do: name

  defp basis_unit_abbreviation(:milliliter), do: "ml"
  defp basis_unit_abbreviation("milliliter"), do: "ml"
  defp basis_unit_abbreviation(_unit), do: "g"

  defp format_basis_quantity(%Decimal{} = quantity) do
    quantity
    |> Decimal.normalize()
    |> Decimal.to_string(:normal)
  end

  defp format_basis_quantity(quantity), do: to_string(quantity)

  # Pricing helper
  defp suggested_price(:retail, unit_cost, settings) do
    apply_markup(unit_cost, settings.retail_markup_mode, settings.retail_markup_value)
  end

  defp suggested_price(:wholesale, unit_cost, settings) do
    apply_markup(unit_cost, settings.wholesale_markup_mode, settings.wholesale_markup_value)
  end

  defp apply_markup(unit_cost, mode, value) do
    unit = unit_cost || Decimal.new(0)
    val = value || Decimal.new(0)

    case mode do
      :percent ->
        Decimal.add(unit, Decimal.mult(unit, Decimal.div(val, Decimal.new(100))))

      :fixed ->
        Decimal.add(unit, val)

      _ ->
        unit
    end
  end

  defp selling_availability_label(:available), do: "Disponible"
  defp selling_availability_label(:preorder), do: "Preventa"
  defp selling_availability_label(:off), do: "Desactivado"

  defp selling_availability_label(status) when is_binary(status),
    do: status |> String.to_existing_atom() |> selling_availability_label()

  defp selling_availability_label(status), do: to_string(status)
end
