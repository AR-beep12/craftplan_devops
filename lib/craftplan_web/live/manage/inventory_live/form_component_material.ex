defmodule CraftplanWeb.InventoryLive.FormComponentMaterial do
  @moduledoc false
  use CraftplanWeb, :live_component

  alias AshPhoenix.Form
  alias Craftplan.Inventory

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        id="material-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Nombre" />
        <.input field={@form[:sku]} type="text" label="SKU" />
        <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <.input field={@form[:price]} type="number" label="Precio" step="0.001" min="0" />
          <.input
            field={@form[:unit]}
            type="radiogroup"
            label="Medido en"
            value={@form[:unit].value || :gram}
            options={[{"Gramo", :gram}, {"Mililitro", :milliliter}, {"Pieza", :piece}]}
          />
        </div>

        <.input
          field={@form[:minimum_stock]}
          type="number"
          label="Stock mínimo"
          inline_label={@form[:unit].value || :gram}
          step="0.001"
          min="0"
        />
        <.input
          field={@form[:maximum_stock]}
          inline_label={@form[:unit].value || :gram}
          type="number"
          label="Stock máximo"
          step="0.001"
          min="0"
        />
        <:actions>
          <.button variant={:primary} phx-disable-with="Guardando...">Guardar material</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok, socket |> assign(assigns) |> assign_form()}
  end

  @impl true
  def handle_event("validate", %{"material" => material_params}, socket) do
    {:noreply, assign(socket, form: Form.validate(socket.assigns.form, material_params))}
  end

  def handle_event("save", %{"material" => material_params}, socket) do
    case Form.submit(socket.assigns.form, params: material_params) do
      {:ok, material} ->
        send(self(), {:saved, material})

        {:noreply,
         socket
         |> put_flash(
           :info,
           "Material #{material_action_label(socket.assigns.form.source.type)} correctamente"
         )
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp material_action_label(:create), do: "creado"
  defp material_action_label(:update), do: "actualizado"
  defp material_action_label(type), do: to_string(type)

  defp assign_form(%{assigns: %{material: material}} = socket) do
    form =
      if material do
        Form.for_update(material, :update,
          as: "material",
          actor: socket.assigns.current_user
        )
      else
        Form.for_create(Inventory.Material, :create,
          as: "material",
          actor: socket.assigns.current_user
        )
      end

    assign(socket, form: to_form(form))
  end
end
