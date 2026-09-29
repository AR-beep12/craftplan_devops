defmodule Craftplan.Orders.Changes.ValidateProductAvailability do
  @moduledoc """
  Validates that products in order items are available (not deactivated).
  Prevents creating orders with products where selling_availability == :off.
  """

  use Ash.Resource.Change

  import Ash.Expr, only: [expr: 1]

  alias Ash.Changeset

  @impl true
  def change(changeset, _opts, context) do
    items_arg = Changeset.get_argument(changeset, :items)

    product_ids =
      extract_product_ids(items_arg) ++ extract_product_ids_from_data(changeset)

    if product_ids == [] do
      changeset
    else
      deactivated_names = get_deactivated_product_names(product_ids, context.actor)

      if deactivated_names == [] do
        changeset
      else
        Changeset.add_error(changeset,
          field: :items,
          message: "Productos desactivados no se pueden pedir: #{Enum.join(deactivated_names, ", ")}"
        )
      end
    end
  end

  defp extract_product_ids(nil), do: []

  defp extract_product_ids(items) when is_list(items) do
    items
    |> Enum.map(fn item ->
      Map.get(item, :product_id) || Map.get(item, "product_id")
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_product_ids(_), do: []

  defp extract_product_ids_from_data(changeset) do
    case changeset.data do
      %{items: items} when is_list(items) ->
        items
        |> Enum.map(fn item -> item.product_id end)
        |> Enum.reject(&is_nil/1)

      %{id: _id} ->
        []

      _ ->
        []
    end
  end

  defp get_deactivated_product_names(product_ids, actor) do
    ids = Enum.uniq(product_ids)

    Craftplan.Catalog.Product
    |> Ash.Query.filter(expr(id in ^ids and selling_availability == :off))
    |> Ash.Query.load(:name)
    |> Ash.read!(actor: actor, authorize?: false)
    |> Enum.map(& &1.name)
  end
end
