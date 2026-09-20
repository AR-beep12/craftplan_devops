defmodule CraftplanWeb.OrderLive.FormComponent do
  @moduledoc false
  use CraftplanWeb, :live_component

  alias AshPhoenix.Form
  alias Craftplan.CRM
  alias Craftplan.Orders

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        id="order-item-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <!-- Cliente buscable con crear inline (mismo patrón que categoría en productos) -->
        <div class="mb-8 space-y-2">
          <div class="flex items-center justify-between">
            <label class="block text-sm font-medium text-stone-700">Cliente</label>
            <button
              :if={@customer_mode == :select}
              type="button"
              phx-click="open_create_customer"
              phx-target={@myself}
              class="text-primary-600 text-sm font-semibold hover:text-primary-700 hover:underline"
            >
              + Crear cliente
            </button>
          </div>
          <input type="hidden" name="order[customer_id]" value={@draft.customer_id} />
          <div
            :if={@customer_mode == :select}
            id="customer-select-widget"
            phx-hook="CategorySearch"
            phx-target={@myself}
            class="relative"
          >
            <input
              type="text"
              value={@customer_query}
              placeholder="Buscar cliente..."
              phx-target={@myself}
              phx-keyup="search_customer"
              phx-change="search_customer"
              name="q"
              autocomplete="off"
              class="block w-full rounded-lg border border-stone-300 px-3 py-2 text-sm shadow-sm focus:border-stone-400 focus:outline-none focus:ring-1 focus:ring-stone-400"
            />
            <div
              :if={@customer_dropdown_open?}
              class="absolute z-10 mt-1 max-h-48 w-full overflow-auto rounded-md border border-stone-200 bg-white shadow-lg"
            >
              <button
                :for={customer <- @filtered_customers}
                type="button"
                phx-click="select_customer"
                phx-value-id={customer.id}
                phx-target={@myself}
                class={[
                  "flex w-full items-center px-3 py-2 text-left text-sm hover:bg-stone-100",
                  @draft.customer_id == customer.id && "bg-stone-100 font-medium"
                ]}
              >
                {customer.full_name}
                <span
                  :if={@draft.customer_id == customer.id}
                  class="ml-auto text-xs text-stone-500"
                >
                  ✓
                </span>
              </button>

              <div :if={@filtered_customers == []} class="px-3 py-2 text-sm text-stone-500">
                Sin resultados
              </div>

              <button
                :if={@show_create_customer?}
                type="button"
                phx-click="init_create_customer"
                phx-value-name={@customer_query}
                phx-target={@myself}
                class="flex w-full items-center gap-2 border-t border-stone-200 bg-stone-50 px-3 py-2 text-left text-sm font-medium text-stone-700 hover:bg-stone-100"
              >
                <.icon name="hero-plus" class="h-4 w-4" /> Crear cliente "{@customer_query}"
              </button>
            </div>
          </div>

          <div
            :if={@customer_mode == :create}
            class="space-y-3 rounded-lg border border-stone-200 bg-stone-50 p-3"
          >
            <div class="flex items-center justify-between">
              <p class="text-sm font-medium text-stone-700">Nuevo cliente</p>

              <button
                type="button"
                phx-click="cancel_create_customer"
                phx-target={@myself}
                class="text-sm font-medium text-stone-500 hover:text-stone-800"
              >
                Elegir existente
              </button>
            </div>

            <div class="grid grid-cols-2 gap-3">
              <.input
                type="text"
                name="new_customer[first_name]"
                value={@new_customer["first_name"]}
                label="Nombre *"
                autocomplete="off"
                phx-change="new_customer_field_change"
                phx-target={@myself}
              />
              <.input
                type="text"
                name="new_customer[last_name]"
                value={@new_customer["last_name"]}
                label="Apellido *"
                autocomplete="off"
                phx-change="new_customer_field_change"
                phx-target={@myself}
              />
              <.input
                type="text"
                name="new_customer[phone]"
                value={@new_customer["phone"]}
                label="Teléfono *"
                autocomplete="off"
                phx-change="new_customer_field_change"
                phx-target={@myself}
              />
              <.input
                type="text"
                name="new_customer[email]"
                value={@new_customer["email"]}
                label="Correo (opcional)"
                autocomplete="off"
                phx-change="new_customer_field_change"
                phx-target={@myself}
              />
            </div>

            <p :if={@new_customer_error} class="text-xs text-red-600">
              {@new_customer_error}
            </p>
          </div>
        </div>

        <div class="mb-8">
          <.input field={@form[:delivery_date]} type="datetime-local" label="Fecha de entrega" />
          <.timezone />
        </div>

        <div class="mb-8">
          <.input
            field={@form[:description]}
            type="textarea"
            label="Descripción"
            placeholder="Notas o detalles del pedido…"
          />
        </div>

        <div class="mb-6">
          <label
            for="product-picker"
            class="block text-sm font-medium text-stone-700"
          >
            Agregar producto
          </label>

          <div
            :if={not Enum.empty?(@available_products)}
            class="mt-2 flex items-end gap-2"
          >
            <div class="grow">
              <.input
                phx-change="selected-product-change"
                phx-target={@myself}
                name="product_id"
                id="product-picker"
                type="select"
                value={@selected_product}
                options={Enum.map(@available_products, &{&1.name, &1.id})}
              />
            </div>

            <.button
              type="button"
              variant={:outline}
              phx-click="add_form"
              phx-target={@myself}
              phx-value-path={@form[:items].name}
            >
              Agregar
            </.button>
          </div>

          <p :if={Enum.empty?(@available_products)} class="mt-2 text-sm text-stone-400">
            Todos los productos ya están agregados.
          </p>
        </div>

        <.label>Artículos</.label>

        <div
          id="order-items"
          class="mt-2 grid w-full grid-cols-4 gap-x-4 text-sm leading-6 text-stone-700"
        >
          <div
            role="row"
            class="col-span-4 grid grid-cols-4 border-b border-stone-300 text-left text-sm leading-6 text-stone-500"
          >
            <div class="border-r border-stone-200 p-0 pr-6 pb-4 font-normal last:border-r-0 ">
              Producto
            </div>

            <div class="border-r border-stone-200 p-0 pr-6 pb-4 pl-4 font-normal last:border-r-0">
              Cantidad
            </div>

            <div class="border-r border-stone-200 p-0 pr-6 pb-4 pl-4 font-normal last:border-r-0">
              Total
            </div>

            <div class="border-r border-stone-200 p-0 pr-6 pb-4 pl-4 font-normal last:border-r-0">
              <span class="opacity-0">Acciones</span>
            </div>
          </div>

          <div role="row" class="col-span-4 hidden py-4 text-stone-400 last:block">
            <div>
              Sin artículos
            </div>
          </div>

          <.inputs_for :let={items_form} field={@form[:items]}>
            <div role="row" class="group col-span-4 grid grid-cols-4 hover:bg-stone-200/40">
              <div class="relative border-r border-b border-stone-200 p-0 last:border-r-0 ">
                <div class="block py-4 pr-6">
                  <span class="relative">
                    {@products_map[items_form[:product_id].value].name}
                    <.input
                      field={items_form[:product_id]}
                      value={items_form[:product_id].value}
                      type="hidden"
                    />
                    <.input
                      field={items_form[:unit_price]}
                      value={@products_map[items_form[:product_id].value].price}
                      type="hidden"
                    />
                  </span>
                </div>
              </div>

              <div class="relative border-r border-b border-stone-200 p-0 pl-4 last:border-r-0">
                <div class="block py-4 pr-6">
                  <span class="relative -mt-2">
                    <div class="border-b border-dashed border-stone-300">
                      <.input flat={true} field={items_form[:quantity]} type="number" min="1" />
                    </div>
                  </span>
                </div>
              </div>

              <div class="relative border-r border-b border-stone-200 p-0 pl-4 last:border-r-0">
                <div class="block py-4 pr-6">
                  <span class="relative">
                    {format_money(
                      @settings.currency,
                      Decimal.mult(
                        @products_map[items_form[:product_id].value].price || 0,
                        items_form[:quantity].value || 0
                      )
                    )}
                  </span>
                </div>
              </div>

              <div class="relative border-r border-b border-stone-200 p-0 pl-4 last:border-r-0">
                <div class="block py-4 pr-6">
                  <.link
                    class="font-semibold leading-6 text-stone-900 hover:text-stone-700"
                    type="button"
                    phx-click="remove_form"
                    phx-target={@myself}
                    phx-value-path={items_form.name}
                  >
                    Quitar
                  </.link>
                </div>
              </div>
            </div>
          </.inputs_for>
        </div>

        <:actions>
          <.button
            variant={:primary}
            disabled={
              not @changed ||
                Enum.empty?((@form.source.forms && @form.source.forms[:items]) || []) ||
                not @customer_ready?
            }
            phx-disable-with="Guardando..."
          >
            Guardar pedido
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    socket = assign_form(socket)

    products_map =
      Map.new(assigns.products, fn p -> {p.id, p} end)

    {available_products, selected_product} =
      recompute_availability(
        socket.assigns.form,
        assigns.products,
        Map.get(socket.assigns, :selected_product)
      )

    {customer_query, filtered_customers} =
      init_customer_state(socket.assigns.form, assigns[:customers] || [])

    draft = %{
      customer_id:
        (socket.assigns.form[:customer_id].value &&
           to_string(socket.assigns.form[:customer_id].value)) ||
          (assigns[:order] && assigns[:order].customer_id)
    }

    {:ok,
     socket
     |> assign(:changed, false)
     |> assign(:draft, draft)
     |> assign(:products_map, products_map)
     |> assign(:available_products, available_products)
     |> assign(:selected_product, selected_product)
     |> assign(:customers, assigns[:customers] || [])
     |> assign(:customer_query, customer_query)
     |> assign(:filtered_customers, filtered_customers)
     |> assign(:customer_dropdown_open?, false)
     |> assign(:customer_mode, :select)
     |> assign(:new_customer, empty_new_customer())
     |> assign(:new_customer_error, nil)
     |> assign_show_create_customer?()
     |> assign_customer_ready?()}
  end

  @impl true
  def handle_event("validate", params, socket) do
    order_params = Map.get(params, "order", %{})

    socket = stash_new_customer(socket, params)

    form = Form.validate(socket.assigns.form, order_params)

    {available_products, selected_product} =
      recompute_availability(
        form,
        socket.assigns.products,
        Map.get(socket.assigns, :selected_product)
      )

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:changed, true)
     |> assign(:available_products, available_products)
     |> assign(:selected_product, selected_product)}
  end

  @impl true
  def handle_event("save", params, socket) do
    order_params = Map.get(params, "order", %{})
    timezone = Map.get(params, "timezone")
    socket = stash_new_customer(socket, params)

    case maybe_create_customer(socket, order_params) do
      {:ok, order_params} ->
        datetime = extract_and_parse_datetime(order_params["delivery_date"], timezone)

        order_params =
          order_params
          |> Map.put(
            "customer_id",
            Map.get(order_params, "customer_id") || socket.assigns.draft.customer_id
          )
          |> Map.put("delivery_date", datetime)
          |> update_in(["items"], &inject_unit_prices(&1, socket.assigns.products_map))

        case Form.submit(socket.assigns.form, params: order_params) do
          {:ok, order} ->
            send(self(), {__MODULE__, {:saved, order}})

            {:noreply,
             socket
             |> put_flash(:info, "Pedido guardado correctamente")
             |> push_patch(to: socket.assigns.patch)}

          {:error, form} ->
            {:noreply, assign(socket, :form, form)}
        end

      {:error, message} ->
        {:noreply, assign(socket, :new_customer_error, message)}
    end
  end

  @impl true
  def handle_event("selected-product-change", %{"product_id" => product_id}, socket) do
    {:noreply, assign(socket, :selected_product, product_id)}
  end

  def handle_event("selected-product-change", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("add_form", %{"path" => path}, socket) do
    form =
      Form.add_form(socket.assigns.form, path,
        params: %{product_id: Map.get(socket.assigns, :selected_product), quantity: 0}
      )

    {available_products, selected_product} =
      recompute_availability(
        form,
        socket.assigns.products,
        Map.get(socket.assigns, :selected_product)
      )

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:changed, true)
     |> assign(:available_products, available_products)
     |> assign(:selected_product, selected_product)}
  end

  @impl true
  def handle_event("remove_form", %{"path" => path}, socket) do
    form = Form.remove_form(socket.assigns.form, path)

    {available_products, selected_product} =
      recompute_availability(
        form,
        socket.assigns.products,
        Map.get(socket.assigns, :selected_product)
      )

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:changed, true)
     |> assign(:available_products, available_products)
     |> assign(:selected_product, selected_product)}
  end

  # --- Cliente buscable (mismo patrón que categoría en productos) ---

  def handle_event("search_customer", params, socket) do
    q =
      Map.get(params, "q") ||
        Map.get(params, "value") ||
        Map.get(params, "_value") || ""

    q = if is_binary(q), do: String.trim(q), else: ""

    {:noreply,
     socket
     |> assign(:customer_query, q)
     |> assign(:filtered_customers, filter_customers(socket.assigns.customers, q))
     |> assign(:customer_dropdown_open?, true)
     |> assign_show_create_customer?()}
  end

  def handle_event("open_dropdown", _params, socket) do
    {:noreply, assign(socket, :customer_dropdown_open?, true)}
  end

  def handle_event("close_dropdown", _params, socket) do
    {:noreply, assign(socket, :customer_dropdown_open?, false)}
  end

  def handle_event("select_customer", %{"id" => id}, socket) do
    customer = Enum.find(socket.assigns.customers, &(&1.id == id))

    # Merge con todos los params ya capturados para NO borrar fecha/artículos
    current_params = stringify_params(socket.assigns.form.source.params || %{})

    form =
      Form.validate(
        socket.assigns.form,
        Map.put(current_params, "customer_id", id)
      )

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:draft, %{socket.assigns.draft | customer_id: id})
     |> assign(:changed, true)
     |> assign(:customer_query, (customer && customer.full_name) || "")
     |> assign(:filtered_customers, socket.assigns.customers)
     |> assign(:customer_dropdown_open?, false)
     |> assign(:customer_mode, :select)
     |> assign(:new_customer_error, nil)
     |> assign_show_create_customer?()
     |> assign_customer_ready?()}
  end

  def handle_event("init_create_customer", %{"name" => raw_name}, socket) do
    enter_create_mode(socket, raw_name)
  end

  def handle_event("open_create_customer", _params, socket) do
    enter_create_mode(socket, socket.assigns.customer_query)
  end

  def handle_event("new_customer_field_change", params, socket) do
    case Map.get(params, "new_customer") do
      %{} = changes ->
        updated = Map.merge(socket.assigns.new_customer, changes)

        {:noreply,
         socket
         |> assign(:changed, true)
         |> assign(:new_customer, updated)
         |> assign_customer_ready?()}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("cancel_create_customer", _params, socket) do
    {:noreply,
     socket
     |> assign(:customer_mode, :select)
     |> assign(:new_customer, empty_new_customer())
     |> assign(:new_customer_error, nil)
     |> assign_customer_ready?()}
  end

  defp enter_create_mode(socket, raw_name) do
    {first_name, last_name} = split_name(raw_name)

    {:noreply,
     socket
     |> assign(:changed, true)
     |> assign(:customer_mode, :create)
     |> assign(:customer_dropdown_open?, false)
     |> assign(:new_customer, %{
       "first_name" => first_name,
       "last_name" => last_name,
       "phone" => "",
       "email" => ""
     })
     |> assign(:new_customer_error, nil)
     |> assign_customer_ready?()}
  end

  defp assign_form(%{assigns: %{order: order}} = socket) do
    form =
      if order do
        Form.for_update(order, :update,
          as: "order",
          actor: socket.assigns.current_user,
          forms: [
            items: [
              type: :list,
              data: order.items,
              resource: Orders.OrderItem,
              create_action: :create,
              update_action: :update
            ]
          ]
        )
      else
        Form.for_create(Orders.Order, :create,
          as: "order",
          actor: socket.assigns.current_user,
          forms: [
            items: [
              type: :list,
              resource: Orders.OrderItem,
              create_action: :create,
              update_action: :update
            ]
          ]
        )
      end

    assign(socket, :form, to_form(form))
  end

  defp recompute_availability(form, all_products, previous_id) do
    # Convert existing product IDs to a MapSet for O(1) membership checks
    existing_product_ids =
      form
      |> get_order_items()
      |> Stream.map(&extract_product_id/1)
      |> Stream.reject(&is_nil/1)
      # MapSet automatically removes duplicates, so we don't need `Enum.uniq/1`
      |> MapSet.new()

    # Reject products whose IDs are in existing_product_ids
    available_products =
      for product <- all_products,
          not MapSet.member?(existing_product_ids, product.id),
          do: product

    # Preserve the previous selection if it's still available, otherwise pick the first
    selected_product =
      if previous_id && Enum.find(available_products, &(&1.id == previous_id)) do
        previous_id
      else
        available_products
        |> List.first()
        |> then(&(&1 && &1.id))
      end

    {available_products, selected_product}
  end

  defp get_order_items(form) do
    form.source.forms[:items] || []
  end

  defp extract_product_id(order_item_form) do
    order_item_form.params[:product_id] ||
      order_item_form.params["product_id"] ||
      (order_item_form.data && order_item_form.data.product_id)
  end

  defp extract_and_parse_datetime(delivery_date, timezone)
       when is_binary(delivery_date) and byte_size(delivery_date) >= 16 do
    datetime = binary_part(delivery_date, 0, 16)

    with {:ok, naive_dt} <- NaiveDateTime.from_iso8601(datetime <> ":00Z"),
         {:ok, dt} <- DateTime.from_naive(naive_dt, timezone || "Etc/UTC") do
      DateTime.to_iso8601(dt)
    else
      _ -> nil
    end
  end

  defp extract_and_parse_datetime(_delivery_date, _timezone), do: nil

  defp stringify_params(params) when is_map(params) do
    Map.new(params, fn {k, v} -> {to_string(k), stringify_params(v)} end)
  end

  defp stringify_params(list) when is_list(list) do
    Enum.map(list, &stringify_params/1)
  end

  defp stringify_params(other), do: other

  # --- Cliente: creación inline ---

  defp empty_new_customer do
    %{"first_name" => "", "last_name" => "", "phone" => "", "email" => ""}
  end

  defp assign_customer_ready?(socket) do
    ready =
      case socket.assigns.customer_mode do
        :select -> not is_nil(socket.assigns.draft.customer_id)
        :create -> new_customer_complete?(socket.assigns.new_customer)
      end

    assign(socket, :customer_ready?, ready)
  end

  defp new_customer_complete?(%{"first_name" => first, "last_name" => last, "phone" => phone}) do
    non_blank?(first) and non_blank?(last) and non_blank?(phone)
  end

  defp non_blank?(value) when is_binary(value), do: String.trim(value) != ""
  defp non_blank?(_value), do: false

  defp stash_new_customer(socket, params) do
    case Map.get(params, "new_customer") do
      %{} = new_customer -> assign(socket, :new_customer, new_customer)
      _ -> socket
    end
  end

  defp maybe_create_customer(%{assigns: %{customer_mode: :create}} = socket, order_params) do
    attrs = blank_to_nil(socket.assigns.new_customer)

    with :ok <- require_new_customer_fields(attrs),
         {:ok, customer} <-
           CRM.create_customer(attrs, actor: socket.assigns.current_user) do
      {:ok, Map.put(order_params, "customer_id", customer.id)}
    else
      {:error, %{errors: errors}} ->
        message = Enum.map_join(errors, ", ", &Exception.message/1)
        {:error, "No se pudo crear el cliente: #{message}"}

      {:error, message} when is_binary(message) ->
        {:error, message}

      {:error, _} ->
        {:error, "No se pudo crear el cliente. Revisa los datos e intenta de nuevo."}
    end
  end

  defp maybe_create_customer(_socket, order_params), do: {:ok, order_params}

  defp blank_to_nil(attrs) do
    Map.new(attrs, fn {k, v} ->
      {k, if(is_binary(v) and String.trim(v) == "", do: nil, else: v)}
    end)
  end

  defp require_new_customer_fields(attrs) do
    cond do
      String.trim(Map.get(attrs, "first_name", "") || "") == "" ->
        {:error, "El nombre del cliente es obligatorio."}

      String.trim(Map.get(attrs, "last_name", "") || "") == "" ->
        {:error, "El apellido del cliente es obligatorio."}

      String.trim(Map.get(attrs, "phone", "") || "") == "" ->
        {:error, "El teléfono del cliente es obligatorio."}

      true ->
        :ok
    end
  end

  defp inject_unit_prices(nil, _products_map), do: nil

  defp inject_unit_prices(items, products_map) when is_map(items) do
    Map.new(items, fn {k, v} ->
      price =
        case products_map[v["product_id"]] do
          %{price: price} -> price
          _ -> Map.get(v, "unit_price", 0)
        end

      {k, Map.put(v, "unit_price", price)}
    end)
  end

  defp inject_unit_prices(items, _products_map), do: items

  # --- Cliente: búsqueda ---

  defp init_customer_state(form, customers) do
    selected_id = form[:customer_id].value

    selected =
      if selected_id do
        Enum.find(customers, &(&1.id == selected_id))
      end

    query =
      if selected do
        selected.full_name || ""
      else
        ""
      end

    {query, customers}
  end

  defp filter_customers(customers, ""), do: customers

  defp filter_customers(customers, query) do
    Enum.filter(customers, fn c ->
      c.full_name
      |> Kernel.||("")
      |> String.downcase()
      |> String.contains?(String.downcase(query))
    end)
  end

  defp assign_show_create_customer?(socket) do
    q = String.trim(socket.assigns.customer_query || "")

    show? =
      socket.assigns.customer_mode == :select and q != "" and
        not Enum.any?(
          socket.assigns.customers,
          &(String.downcase(&1.full_name || "") == String.downcase(q))
        ) and
        String.length(q) >= 2

    assign(socket, :show_create_customer?, show?)
  end

  defp split_name(raw_name) do
    parts =
      (raw_name || "")
      |> String.trim()
      |> String.split(~r/\s+/, trim: true)

    case parts do
      [] -> {"", ""}
      [first] -> {first, ""}
      [first | rest] -> {first, Enum.join(rest, " ")}
    end
  end
end
