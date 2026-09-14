defmodule CraftplanWeb.CommandPaletteSearch do
  @moduledoc """
  Search functionality for the command palette.
  Provides static pages/actions and Ash-powered entity search.
  """
  import Ash.Query

  @pages [
    %{label: "Pedidos", path: "/manage/orders", icon: :orders},
    %{label: "Productos", path: "/manage/products", icon: :products},
    %{label: "Inventario", path: "/manage/inventory", icon: :inventory},
    %{label: "Clientes", path: "/manage/customers", icon: :customers},
    %{label: "Configuración", path: "/manage/settings", icon: :settings}
  ]

  @actions [
    %{label: "Nuevo pedido", path: "/manage/orders/new", icon: :orders},
    %{label: "Nuevo producto", path: "/manage/products/new", icon: :products},
    %{label: "Nuevo material", path: "/manage/inventory/new", icon: :inventory},
    %{label: "Nuevo cliente", path: "/manage/customers/new", icon: :customers}
  ]

  @doc """
  Searches all categories and returns grouped results.
  """
  def search(query, actor) when is_binary(query) do
    query = String.trim(query)

    if query == "" do
      %{
        pages: @pages,
        actions: @actions,
        products: [],
        materials: [],
        orders: [],
        customers: []
      }
    else
      %{
        pages: search_static(@pages, query),
        actions: search_static(@actions, query),
        products: search_products(query, actor),
        materials: search_materials(query, actor),
        orders: search_orders(query, actor),
        customers: search_customers(query, actor)
      }
    end
  end

  @doc """
  Returns all results as a flat list for keyboard navigation.
  """
  def flatten_results(results) do
    List.flatten([
      Enum.map(results.pages, &Map.put(&1, :category, :pages)),
      Enum.map(results.actions, &Map.put(&1, :category, :actions)),
      Enum.map(results.products, &Map.put(&1, :category, :products)),
      Enum.map(results.materials, &Map.put(&1, :category, :materials)),
      Enum.map(results.orders, &Map.put(&1, :category, :orders)),
      Enum.map(results.customers, &Map.put(&1, :category, :customers))
    ])
  end

  defp search_static(items, query) do
    pattern = String.downcase(query)

    items
    |> Enum.filter(fn item ->
      String.contains?(String.downcase(item.label), pattern)
    end)
    |> Enum.take(5)
  end

  defp search_products(query, actor) do
    pattern = "%#{query}%"

    Craftplan.Catalog.Product
    |> filter(ilike(name, ^pattern))
    |> limit(5)
    |> Ash.read!(actor: actor)
    |> Enum.map(fn p ->
      %{
        label: p.name,
        sublabel: p.category && p.category.name || "",
        path: "/manage/products/#{p.id}",
        icon: :products
      }
    end)
  rescue
    _ -> []
  end

  defp search_materials(query, actor) do
    pattern = "%#{query}%"

    Craftplan.Inventory.Material
    |> filter(ilike(name, ^pattern))
    |> limit(5)
    |> Ash.read!(actor: actor)
    |> Enum.map(fn m ->
      %{
        label: m.name,
        sublabel: m.color || m.extra_description || "",
        path: "/manage/inventory/#{m.id}",
        icon: :inventory
      }
    end)
  rescue
    _ -> []
  end

  defp search_orders(query, actor) do
    pattern = "%#{query}%"

    Craftplan.Orders.Order
    |> filter(ilike(reference, ^pattern))
    |> limit(5)
    |> Ash.read!(actor: actor)
    |> Enum.map(fn o ->
      %{
        label: o.reference,
        sublabel: format_date(o.delivery_date),
        path: "/manage/orders/#{o.reference}",
        icon: :orders
      }
    end)
  rescue
    _ -> []
  end

  defp search_customers(query, actor) do
    pattern = "%#{query}%"

    Craftplan.CRM.Customer
    |> filter(ilike(first_name, ^pattern) or ilike(last_name, ^pattern) or ilike(reference, ^pattern))
    |> limit(5)
    |> Ash.read!(actor: actor)
    |> Enum.map(fn c ->
      %{
        label: "#{c.first_name} #{c.last_name}",
        sublabel: c.reference,
        path: "/manage/customers/#{c.reference}",
        icon: :customers
      }
    end)
  rescue
    _ -> []
  end

  defp format_date(nil), do: nil

  defp format_date(date) do
    Calendar.strftime(date, "%b %d, %Y")
  end
end

