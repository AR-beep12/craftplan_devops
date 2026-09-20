defmodule CraftplanWeb.SettingsLive.AllergensComponent do
  @moduledoc false
  use CraftplanWeb, :live_component

  alias Craftplan.Inventory
  alias Craftplan.Inventory.Allergen

  @impl true
  def render(assigns) do
    assigns = assign_new(assigns, :show_modal, fn -> false end)

    ~H"""
    <div class="space-y-6">
      <.header>
        <:subtitle>
          Busca y gestiona los alérgenos disponibles en tus productos y materiales.
        </:subtitle>
        Alérgenos
      </.header>

      <div class="flex flex-col gap-6 lg:flex-row">
        <div class="flex-1">
          <div class="rounded-md border border-gray-200 bg-white">
            <div class="border-t border-stone-200 px-4 py-4">
              <form
                id="allergen-filter"
                phx-change="filter_allergens"
                phx-submit="filter_allergens"
                phx-target={@myself}
                class="space-y-4"
              >
                <label class="sr-only text-sm font-medium text-stone-700" for="allergen-filter-query">
                  Buscar alérgenos
                </label>

                <input
                  id="allergen-filter-query"
                  name="query"
                  type="search"
                  value={@search_query}
                  placeholder="Escribe para filtrar por nombre..."
                  phx-debounce="300"
                  class="w-full rounded-md border border-stone-300 bg-white px-3 py-2 text-sm text-stone-900 transition focus:border-primary-400 focus:ring-primary-200/60 focus:outline-none focus:ring"
                />
              </form>
            </div>

            <div class="-mt-10 p-4">
              <.table id="allergens" rows={@visible_allergens} wrapper_class="mt-0">
                <:col :let={allergen} label="Nombre">{allergen.name}</:col>

                <:action :let={allergen}>
                  <.link
                    phx-click={JS.push("delete", value: %{id: allergen.id}, target: @myself)}
                    data-confirm="¿Estás seguro de que deseas eliminar este alérgeno? Esta acción no se puede deshacer."
                  >
                    <.button size={:sm} variant={:danger}>
                      Eliminar
                    </.button>
                  </.link>
                </:action>

                <:empty>
                  <div class="py-6 text-center text-sm text-stone-500">
                    {if String.trim(@search_query) == "" do
                      "Aún no hay alérgenos. Agrega tu primer alérgeno desde el panel de gestión."
                    else
                      "Ningún alérgeno coincide con tu búsqueda."
                    end}
                  </div>
                </:empty>
              </.table>
            </div>
          </div>
        </div>

        <aside class="lg:w-80">
          <div class="space-y-4 rounded-md border border-gray-200 bg-white p-4">
            <h3 class="text-sm font-semibold text-stone-800">Gestionar</h3>

            <p class="text-sm text-stone-600">
              Crea nuevos alérgenos o elimina los que ya no necesites rastrear. Los cambios se aplican de inmediato en todo Craftplan.
            </p>

            <.button
              type="button"
              variant={:primary}
              class="w-full justify-center"
              phx-click="show_add_modal"
              phx-target={@myself}
            >
              <.icon name="hero-plus" class="mr-2 h-4 w-4" /> Agregar alérgeno
            </.button>
          </div>
        </aside>
      </div>

      <.modal
        :if={@show_modal}
        id="add-allergen-modal"
        show
        title="Agregar nuevo alérgeno"
        description="Ingresa el nombre del alérgeno que deseas agregar"
        on_cancel={JS.push("hide_modal", target: @myself)}
      >
        <.simple_form
          for={@form}
          id="allergen-form"
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save"
        >
          <.input field={@form[:name]} type="text" label="Nombre del alérgeno" />
          <:actions>
            <.button variant={:primary} phx-disable-with="Guardando...">Guardar alérgeno</.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    allergens = Inventory.list_allergens!()
    form = new_allergen_form(assigns.current_user)
    search_query = Map.get(socket.assigns, :search_query, "")

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:allergens, allergens)
     |> assign(:search_query, search_query)
     |> assign(:visible_allergens, filter_allergens(allergens, search_query))
     |> assign(:form, form)
     |> assign(:show_modal, false)}
  end

  @impl true
  def handle_event("validate", %{"allergen" => allergen_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, allergen_params)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"allergen" => allergen_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: allergen_params) do
      {:ok, _allergen} ->
        # Notify parent to reload allergens
        send(self(), {:saved_allergens, nil})

        allergens = Inventory.list_allergens!()

        socket =
          socket
          |> assign(:form, new_allergen_form(socket.assigns.current_user))
          |> assign(:show_modal, false)
          |> assign(:allergens, allergens)
          |> assign_filtered_allergens(socket.assigns.search_query)

        {:noreply, put_flash(socket, :info, "Alérgeno agregado correctamente")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    allergen = Inventory.get_allergen_by_id!(id)
    :ok = Inventory.destroy_allergen!(allergen, actor: socket.assigns.current_user)

    # Notify parent to reload allergens
    send(self(), {:saved_allergens, nil})

    allergens = Inventory.list_allergens!()

    socket =
      socket
      |> assign(:allergens, allergens)
      |> assign_filtered_allergens(socket.assigns.search_query)

    {:noreply, put_flash(socket, :info, "Alérgeno eliminado correctamente")}
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
  def handle_event("filter_allergens", params, socket) do
    query =
      params
      |> Map.get("query", "")
      |> String.trim()

    {:noreply, socket |> assign(:search_query, query) |> assign_filtered_allergens(query)}
  end

  defp new_allergen_form(user) do
    Allergen
    |> AshPhoenix.Form.for_create(:create,
      actor: user,
      as: "allergen"
    )
    |> to_form()
  end

  defp assign_filtered_allergens(socket, query) do
    assign(socket, :visible_allergens, filter_allergens(socket.assigns.allergens, query))
  end

  defp filter_allergens(allergens, ""), do: allergens

  defp filter_allergens(allergens, query) do
    downcased = String.downcase(query)

    Enum.filter(allergens, fn allergen ->
      allergen.name
      |> to_string()
      |> String.downcase()
      |> String.contains?(downcased)
    end)
  end
end
