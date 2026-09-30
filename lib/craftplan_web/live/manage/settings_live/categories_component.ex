defmodule CraftplanWeb.SettingsLive.CategoriesComponent do
  @moduledoc false
  use CraftplanWeb, :live_component

  import Ecto.Query

  alias Craftplan.Catalog
  alias Craftplan.Catalog.Category

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:show_modal, fn -> false end)
      |> assign_new(:settings, fn -> nil end)

    ~H"""
    <div class="space-y-6">
      <.header>
        <:subtitle>
          Configura la moneda predeterminada.
        </:subtitle>
        General
      </.header>

      <section
        id="general-settings"
        aria-labelledby="general-settings-title"
        class="rounded-md border border-gray-200 bg-white"
      >
        <div class="border-b border-stone-200 px-4 py-3">
          <h3 id="general-settings-title" class="text-base font-semibold text-stone-800">
            Moneda predeterminada
          </h3>

          <p class="mt-1 text-sm text-stone-600">
            Define la moneda utilizada en pedidos, facturas e informes.
          </p>
        </div>

        <div class="space-y-4 p-4">
          <.simple_form
            :if={@settings}
            for={@settings_form}
            id="settings-form"
            phx-target={@myself}
            phx-change="validate_settings"
            phx-submit="save_settings"
          >
            <.input
              field={@settings_form[:currency]}
              type="select"
              options={currency_options()}
              label="Moneda predeterminada"
            />
            <:actions>
              <.button variant={:primary} phx-disable-with="Guardando...">Guardar</.button>
            </:actions>
          </.simple_form>
        </div>
      </section>

      <.header>
        <:subtitle>
          Gestiona las categorías de productos.
        </:subtitle>
        Categorias
      </.header>

      <div class="flex flex-col gap-6 lg:flex-row">
        <div class="flex-1">
          <div class="rounded-md border border-gray-200 bg-white">
            <div class="border-t border-stone-200 px-4 py-4">
              <form
                id="category-filter"
                phx-change="filter_categories"
                phx-submit="filter_categories"
                phx-target={@myself}
                class="space-y-4"
              >
                <label class="sr-only text-sm font-medium text-stone-700" for="category-filter-query">
                  Buscar categorías
                </label>

                <input
                  id="category-filter-query"
                  name="query"
                  type="search"
                  value={@search_query}
                  placeholder="Escribe para filtrar por nombre..."
                  phx-debounce="300"
                  class="w-full rounded-md border border-stone-300 bg-white px-3 py-2 text-sm text-stone-900 transition focus:border-primary-400 focus:ring-primary-200/60 focus:outline-none focus:ring"
                />
              </form>
            </div>

            <div class="p-4">
              <div class="max-h-96 overflow-y-auto rounded-md border border-stone-200">
                <div :if={@visible_categories == []} class="py-8 text-center text-sm text-stone-500">
                  {if String.trim(@search_query) == "" do
                    "Aún no hay categorías. Agrega tu primera categoría."
                  else
                    "Ninguna categoría coincide con tu búsqueda."
                  end}
                </div>

                <div
                  :for={category <- @visible_categories}
                  class="flex items-center gap-3 border-b border-stone-100 px-4 py-3 last:border-b-0 hover:bg-stone-50"
                >
                  <input
                    type="checkbox"
                    checked={category.active}
                    phx-click="toggle_active"
                    phx-value-id={category.id}
                    phx-target={@myself}
                    class="text-primary-600 h-4 w-4 rounded border-stone-300 focus:ring-primary-500"
                  />
                  <div class="min-w-0 flex-1">
                    <p class={[
                      "truncate text-sm font-medium",
                      if(category.active, do: "text-stone-900", else: "text-stone-400 line-through")
                    ]}>
                      {category.name}
                    </p>

                    <p class="truncate text-xs text-stone-500">{category.slug}</p>
                  </div>

                  <span class={[
                    "inline-flex rounded-full px-2 py-0.5 text-xs font-medium",
                    if(category.active,
                      do: "bg-green-100 text-green-700",
                      else: "bg-stone-200 text-stone-600"
                    )
                  ]}>
                    {if category.active, do: "Activa", else: "Oculta"}
                  </span>

                  <.link
                    phx-click={JS.push("delete", value: %{id: category.id}, target: @myself)}
                    data-confirm="¿Eliminar categoría '#{category.name}'? Los productos con esta categoría quedarán sin categoría."
                  >
                    <.button size={:sm} variant={:danger}>
                      Eliminar
                    </.button>
                  </.link>
                </div>
              </div>

              <p class="mt-3 text-xs text-stone-500">
                {length(@visible_categories)} de {length(@categories)} categorías — desmarca para ocultar del formulario de productos.
              </p>
            </div>
          </div>
        </div>

        <aside class="lg:w-80">
          <div class="space-y-4 rounded-md border border-gray-200 bg-white p-4">
            <h3 class="text-sm font-semibold text-stone-800">Gestionar</h3>

            <p class="text-sm text-stone-600">
              Crea nuevas categorías o gestiona las existentes. Solo las categorías activas aparecen en el selector del popup de producto.
            </p>

            <.button
              type="button"
              variant={:primary}
              class="w-full justify-center"
              phx-click="show_add_modal"
              phx-target={@myself}
            >
              <.icon name="hero-plus" class="mr-2 h-4 w-4" /> Agregar categoría
            </.button>
          </div>
        </aside>
      </div>

      <.modal
        :if={@show_modal}
        id="add-category-modal"
        show
        title="Agregar nueva categoría"
        description="Ingresa el nombre de la categoría"
        on_cancel={JS.push("hide_modal", target: @myself)}
      >
        <.simple_form
          for={@form}
          id="category-form"
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save"
        >
          <.input
            field={@form[:name]}
            type="text"
            label="Nombre de la categoría"
            placeholder="Ej: Sticker, Camisetas..."
          />
          <:actions>
            <.button variant={:primary} phx-disable-with="Guardando...">Guardar categoría</.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    categories =
      [actor: assigns[:current_user] || nil]
      |> Catalog.list_categories!()
      |> Enum.sort_by(& &1.name)

    form = new_category_form(assigns.current_user)
    search_query = Map.get(socket.assigns, :search_query, "")

    settings_form =
      if assigns[:settings] do
        AshPhoenix.Form.for_update(assigns.settings, :update,
          as: "settings",
          actor: assigns[:current_user]
        )
        |> to_form()
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:categories, categories)
     |> assign(:search_query, search_query)
     |> assign(:visible_categories, filter_categories(categories, search_query))
     |> assign(:form, form)
     |> assign(:settings_form, settings_form)
     |> assign(:show_modal, false)}
  end

  @impl true
  def handle_event("validate_settings", %{"settings" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.settings_form, params)
    {:noreply, assign(socket, :settings_form, form)}
  end

  @impl true
  def handle_event("save_settings", %{"settings" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.settings_form, params: params) do
      {:ok, settings} ->
        {:noreply,
         socket
         |> assign(:settings, settings)
         |> put_flash(:info, "Configuración actualizada correctamente")}

      {:error, form} ->
        {:noreply, assign(socket, :settings_form, form)}
    end
  end

  @impl true
  def handle_event("validate", %{"category" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"category" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _category} ->
        categories =
          [actor: socket.assigns.current_user]
          |> Catalog.list_categories!()
          |> Enum.sort_by(& &1.name)

        {:noreply,
         socket
         |> assign(:categories, categories)
         |> assign(
           :visible_categories,
           filter_categories(categories, socket.assigns.search_query)
         )
         |> assign(:form, new_category_form(socket.assigns.current_user))
         |> assign(:show_modal, false)
         |> put_flash(:info, "Categoría agregada correctamente")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    category = Catalog.get_category_by_id!(id, actor: socket.assigns.current_user)

    # Desvincula productos antes de borrar para evitar FK
    Craftplan.Repo.update_all(
      from(p in Craftplan.Catalog.Product, where: p.category_id == ^id),
      set: [category_id: nil]
    )

    case Ash.destroy(category, actor: socket.assigns.current_user) do
      :ok ->
        categories =
          [actor: socket.assigns.current_user]
          |> Catalog.list_categories!()
          |> Enum.sort_by(& &1.name)

        {:noreply,
         socket
         |> assign(:categories, categories)
         |> assign(
           :visible_categories,
           filter_categories(categories, socket.assigns.search_query)
         )
         |> put_flash(:info, "Categoría eliminada correctamente")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, "No se pudo eliminar: #{inspect(error)}")}
    end
  end

  @impl true
  def handle_event("toggle_active", %{"id" => id}, socket) do
    category = Catalog.get_category_by_id!(id, actor: socket.assigns.current_user)

    case Catalog.update_category(category, %{active: !category.active},
           actor: socket.assigns.current_user
         ) do
      {:ok, _} ->
        categories =
          [actor: socket.assigns.current_user]
          |> Catalog.list_categories!()
          |> Enum.sort_by(& &1.name)

        {:noreply,
         socket
         |> assign(:categories, categories)
         |> assign(
           :visible_categories,
           filter_categories(categories, socket.assigns.search_query)
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "No se pudo actualizar la categoría")}
    end
  end

  @impl true
  def handle_event("show_add_modal", _, socket) do
    {:noreply, assign(socket, :show_modal, true)}
  end

  @impl true
  def handle_event("hide_modal", _, socket) do
    {:noreply, assign(socket, :show_modal, false)}
  end

  @impl true
  def handle_event("filter_categories", params, socket) do
    query = params |> Map.get("query", "") |> String.trim()

    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:visible_categories, filter_categories(socket.assigns.categories, query))}
  end

  defp new_category_form(user) do
    Category
    |> AshPhoenix.Form.for_create(:create, actor: user, as: "category")
    |> to_form()
  end

  @priority_currencies [:USD, :EUR]

  defp currency_options do
    priority_options = Enum.map(@priority_currencies, &{currency_display_name(&1), &1})

    rest_options =
      Craftplan.Types.Currency.values()
      |> Enum.reject(&(&1 in @priority_currencies))
      |> Enum.map(&{currency_display_name(&1), &1})
      |> Enum.reject(fn {name, _code} -> is_nil(name) end)
      |> Enum.sort_by(fn {name, _code} -> name end)

    priority_options ++ rest_options
  end

  defp currency_display_name(code) do
    code
    |> Cldr.Currency.display_name!(backend: Craftplan.Cldr, locale: "es")
    |> capitalize_first()
  rescue
    _ -> code |> to_string() |> String.upcase()
  end

  defp capitalize_first(<<first::utf8, rest::binary>>), do: String.upcase(<<first::utf8>>) <> rest
  defp capitalize_first(other), do: other

  defp filter_categories(categories, ""), do: categories

  defp filter_categories(categories, query) do
    down = String.downcase(query)

    Enum.filter(categories, fn c ->
      String.contains?(String.downcase(c.name), down) or
        String.contains?(String.downcase(c.slug), down)
    end)
  end
end
