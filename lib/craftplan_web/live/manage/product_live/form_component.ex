defmodule CraftplanWeb.ProductLive.FormComponent do
  @moduledoc false
  use CraftplanWeb, :live_component

  alias Craftplan.Catalog

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        id="product-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <!-- Categoría buscable con crear -->
        <div class="space-y-2">
          <label class="block text-sm font-medium text-stone-700">Categoría</label>
          <.input field={@form[:category_id]} type="hidden" />
          <div
            id="category-select-widget"
            phx-hook="CategorySearch"
            phx-target={@myself}
            class="relative"
          >
            <input
              type="text"
              value={@category_query}
              placeholder="Buscar o escribir categoría..."
              phx-target={@myself}
              phx-keyup="search_category"
              phx-change="search_category"
              name="q"
              autocomplete="off"
              class="block w-full rounded-lg border border-stone-300 px-3 py-2 text-sm shadow-sm focus:border-stone-400 focus:outline-none focus:ring-1 focus:ring-stone-400"
            />
            <div
              :if={@dropdown_open?}
              class="absolute z-10 mt-1 max-h-48 w-full overflow-auto rounded-md border border-stone-200 bg-white shadow-lg"
            >
              <button
                :for={cat <- @filtered_categories}
                type="button"
                phx-click="select_category"
                phx-value-id={cat.id}
                phx-target={@myself}
                class={[
                  "flex w-full items-center px-3 py-2 text-left text-sm hover:bg-stone-100",
                  @form[:category_id].value == cat.id && "bg-stone-100 font-medium"
                ]}
              >
                {cat.name}
                <span :if={@form[:category_id].value == cat.id} class="ml-auto text-xs text-stone-500">✓</span>
              </button>

              <div :if={@filtered_categories == []} class="px-3 py-2 text-sm text-stone-500">
                Sin resultados
              </div>

              <button
                :if={@show_create?}
                type="button"
                phx-click="create_category"
                phx-value-name={@category_query}
                phx-target={@myself}
                class="flex w-full items-center gap-2 border-t border-stone-200 bg-stone-50 px-3 py-2 text-left text-sm font-medium text-stone-700 hover:bg-stone-100"
              >
                <.icon name="hero-plus" class="h-4 w-4" /> Crear categoría "{@category_query}"
              </button>
            </div>
          </div>

          <p :if={@form[:category_id].errors != []} class="text-xs text-red-600">
            {Enum.map_join(@form[:category_id].errors, ", ", fn {msg, _} -> msg end)}
          </p>
        </div>
        <.input field={@form[:name]} type="text" label="Nombre" />
        <.input field={@form[:price]} type="number" label="Precio" step="0.01" />
        <.input
          field={@form[:selling_availability]}
          type="radiogroup"
          label="Disponibilidad de venta"
          options={[
            {"Disponible", :available},
            {"Preventa", :preorder},
            {"Desactivado", :off}
          ]}
        />
        <:actions>
          <.button variant={:primary} phx-disable-with="Guardando...">Guardar producto</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    categories =
      [actor: assigns[:current_user] || nil]
      |> Catalog.list_categories!()
      |> Enum.sort_by(& &1.name)

    product = assigns[:product]

    # Determine initial category query / selected id
    {initial_query, _selected_id} =
      cond do
        product && is_map(product) && Map.get(product, :category) && product.category &&
            product.category.name ->
          {product.category.name, product.category.id}

        product && Map.get(product, :category_id) ->
          cat = Enum.find(categories, &(&1.id == product.category_id))
          {(cat && cat.name) || "", product.category_id}

        true ->
          # from form if editing (fallback)
          {"", nil}
      end

    active_categories = Enum.filter(categories, & &1.active)

    # If form already has a value (e.g. after validate), prefer it
    socket =
      socket
      |> assign(assigns)
      |> assign(:categories, categories)
      |> assign(:filtered_categories, active_categories)
      |> assign(:category_query, initial_query)
      |> assign(:dropdown_open?, false)
      |> assign_form()
      |> assign_selected_category_name()
      |> assign_show_create?()

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"product" => product_params}, socket) do
    {:noreply,
     socket
     |> assign(
       :form,
       socket.assigns.form |> AshPhoenix.Form.validate(product_params) |> to_form()
     )
     |> assign_selected_category_name()
     |> assign_show_create?()}
  end

  def handle_event("search_category", params, socket) do
    q =
      Map.get(params, "q") ||
        Map.get(params, "value") ||
        Map.get(params, "_value") || ""

    # phx-keyup sends %{"_target" => ["q"], "q" => "..."} or %{"q" => "..."}
    q = if is_binary(q), do: String.trim(q), else: ""

    active_categories = Enum.filter(socket.assigns.categories, & &1.active)

    filtered =
      if q == "" do
        active_categories
      else
        Enum.filter(active_categories, fn c ->
          String.contains?(String.downcase(c.name), String.downcase(q))
        end)
      end

    {:noreply,
     socket
     |> assign(:category_query, q)
     |> assign(:filtered_categories, filtered)
     |> assign(:dropdown_open?, true)
     |> assign_show_create?()}
  end

  def handle_event("open_dropdown", _params, socket) do
    {:noreply, assign(socket, :dropdown_open?, true)}
  end

  def handle_event("close_dropdown", _params, socket) do
    {:noreply, assign(socket, :dropdown_open?, false)}
  end

  def handle_event("select_category", %{"id" => id}, socket) do
    category = Enum.find(socket.assigns.categories, &(&1.id == id))

    form =
      socket.assigns.form
      |> AshPhoenix.Form.validate(%{"category_id" => id})
      |> to_form()

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:category_query, (category && category.name) || "")
     |> assign(:filtered_categories, Enum.filter(socket.assigns.categories, & &1.active))
     |> assign(:dropdown_open?, false)
     |> assign_selected_category_name()
     |> assign_show_create?()}
  end

  def handle_event("create_category", %{"name" => raw_name}, socket) do
    name = String.trim(raw_name || "")

    if name == "" do
      {:noreply, socket}
    else
      # Avoid duplicate (case-insensitive)
      existing =
        Enum.find(socket.assigns.categories, &(String.downcase(&1.name) == String.downcase(name)))

      if existing do
        # Just select it
        form =
          socket.assigns.form
          |> AshPhoenix.Form.validate(%{"category_id" => existing.id})
          |> to_form()

        {:noreply,
         socket
         |> assign(:form, form)
         |> assign(:category_query, existing.name)
         |> assign(:dropdown_open?, false)
         |> assign_selected_category_name()
         |> assign_show_create?()}
      else
        case Catalog.create_category(%{name: name}, actor: socket.assigns.current_user) do
          {:ok, cat} ->
            categories = Enum.sort_by([cat | socket.assigns.categories], & &1.name)

            form =
              socket.assigns.form
              |> AshPhoenix.Form.validate(%{"category_id" => cat.id})
              |> to_form()

            {:noreply,
             socket
             |> assign(:categories, categories)
             |> assign(:filtered_categories, Enum.filter(categories, & &1.active))
             |> assign(:category_query, cat.name)
             |> assign(:form, form)
             |> assign(:dropdown_open?, false)
             |> assign_selected_category_name()
             |> assign_show_create?()
             |> put_flash(:info, "Categoría \"#{cat.name}\" creada")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "No se pudo crear la categoría")}
        end
      end
    end
  end

  def handle_event("save", %{"product" => product_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: product_params) do
      {:ok, product} ->
        notify_parent({:saved, product})

        {:noreply,
         socket
         |> put_flash(
           :info,
           "Producto #{if socket.assigns.form.source.type == :create, do: "creado", else: "actualizado"} correctamente"
         )
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply,
         socket
         |> assign(form: to_form(form))
         |> assign_selected_category_name()
         |> assign_show_create?()}
    end
  end

  defp assign_form(%{assigns: %{product: product}} = socket) do
    form =
      if product do
        AshPhoenix.Form.for_update(product, :update,
          as: "product",
          actor: socket.assigns.current_user
        )
      else
        AshPhoenix.Form.for_create(Craftplan.Catalog.Product, :create,
          as: "product",
          actor: socket.assigns.current_user
        )
      end

    assign(socket, form: to_form(form))
  end

  defp assign_selected_category_name(socket) do
    selected_id = socket.assigns.form[:category_id].value

    name =
      if selected_id,
        do:
          Enum.find_value(socket.assigns.categories, nil, fn c ->
            if c.id == selected_id, do: c.name
          end)

    assign(socket, :selected_category_name, name)
  end

  defp assign_show_create?(socket) do
    q = String.trim(socket.assigns.category_query || "")

    show? =
      q != "" and
        not Enum.any?(
          socket.assigns.categories,
          &(String.downcase(&1.name) == String.downcase(q))
        ) and
        String.length(q) >= 2

    assign(socket, :show_create?, show?)
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
