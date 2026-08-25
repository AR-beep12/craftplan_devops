defmodule CraftplanWeb.ProductLive.FormComponent do
  @moduledoc false
  use CraftplanWeb, :live_component

  alias Craftplan.Inventory

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
        <.input field={@form[:name]} type="text" label="Nombre" />
        <.input field={@form[:sku]} type="text" label="SKU" />
        <.input field={@form[:price]} type="number" label="Precio" />

        <.input
          field={@form[:status]}
          type="radiogroup"
          label="Estado"
          options={[
            {"Borrador", :draft},
            {"En prueba", :testing},
            {"Activo", :active},
            {"Pausado", :paused},
            {"Descontinuado", :discontinued},
            {"Archivado", :archived}
          ]}
        />

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

        <.input
          field={@form[:max_daily_quantity]}
          type="number"
          min="0"
          label="Unidades máximas por día (0 = ilimitado)"
        />

        <div class="grid gap-4 sm:grid-cols-2">
          <.input
            field={@form[:nutrition_output_quantity]}
            type="number"
            min="0"
            step="0.01"
            label="Producción final"
          />
          <.input
            field={@form[:nutrition_output_unit]}
            type="select"
            label="Unidad de producción"
            options={[{"Gramo (g)", :gram}, {"Mililitro (ml)", :milliliter}]}
          />
        </div>

        <:actions>
          <.button variant={:primary} phx-disable-with="Guardando...">Guardar producto</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    materials = Inventory.list_materials!(actor: socket.assigns[:current_user])
    {:ok, socket |> assign(assigns) |> assign(:materials, materials) |> assign_form()}
  end

  @impl true
  def handle_event("validate", %{"product" => product_params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, product_params))}
  end

  def handle_event("save", %{"product" => product_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: product_params) do
      {:ok, product} ->
        notify_parent({:saved, product})

        {:noreply,
         socket
         |> put_flash(:info, "Producto #{if socket.assigns.form.source.type == :create, do: "creado", else: "actualizado"} correctamente")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
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

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
