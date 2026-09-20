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
        <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <.input field={@form[:name]} type="text" label="Nombre" />
          <.input field={@form[:color]} type="text" label="Color" />
        </div>
        <div :if={@material} class="rounded-md border border-stone-200 bg-stone-50 p-3">
          <div class="text-xs font-medium text-stone-500">Stock actual</div>
          <div class="text-sm font-semibold text-stone-900">
            {format_quantity(@material.current_stock)}
            <span class="font-normal text-stone-500">— usa Ajustar stock para modificar</span>
          </div>
        </div>
        <.input
          :if={!@material}
          field={@form[:quantity]}
          type="number"
          label="Cantidad inicial"
          step="0.5"
          phx-debounce="blur"
        />
        <.input field={@form[:extra_description]} type="textarea" label="Descripción" />
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
    is_create = socket.assigns.form.source.type == :create

    case Form.submit(socket.assigns.form, params: material_params) do
      {:ok, material} ->
        # Si es creación y se ingresó cantidad, crear movimiento inicial para que stock actual refleje esa cantidad
        material =
          if is_create and not is_nil(material.quantity) do
            qty = material.quantity

            qty_decimal =
              case qty do
                %Decimal{} = d -> d
                other -> Decimal.new(to_string(other))
              end

            if Decimal.compare(qty_decimal, Decimal.new(0)) == :eq do
              material
              # Crear movimiento inicial
            else
              case Inventory.Movement
                   |> Ash.Changeset.for_create(:adjust_stock, %{
                     material_id: material.id,
                     quantity: qty_decimal,
                     reason: "Stock inicial"
                   })
                   |> Ash.create(actor: socket.assigns.current_user) do
                {:ok, _movement} ->
                  Ash.load!(material, :current_stock, actor: socket.assigns.current_user)

                {:error, _} ->
                  material
              end
            end
          else
            material
          end

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

  defp format_quantity(nil), do: "0"

  defp format_quantity(%Decimal{} = qty), do: qty |> Decimal.normalize() |> Decimal.to_string(:normal)

  defp format_quantity(qty) when is_number(qty), do: to_string(qty)
  defp format_quantity(qty), do: to_string(qty)

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
