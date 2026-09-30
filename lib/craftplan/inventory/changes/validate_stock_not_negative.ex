defmodule Craftplan.Inventory.Changes.ValidateStockNotNegative do
  @moduledoc """
  Blocks stock adjustments that would leave a balance below zero.

  Stock is derived from the sum of the movements, so the only place to guard it
  is while a movement is written. Positive movements are always allowed; a
  negative movement is rejected when the resulting balance of the material (or
  of the lot, when the movement targets one) would drop below zero. Reaching
  exactly zero is allowed.
  """

  use Ash.Resource.Change

  alias Ash.Changeset
  alias Craftplan.Inventory.Lot
  alias Craftplan.Inventory.Material
  alias Decimal, as: D

  @impl true
  def change(changeset, _opts, _context) do
    Changeset.before_action(changeset, &validate/1)
  end

  defp validate(changeset) do
    case Changeset.get_attribute(changeset, :quantity) do
      %D{} = quantity ->
        changeset
        |> guard(Material, :material_id, "material", quantity)
        |> guard(Lot, :lot_id, "lote", quantity)

      _ ->
        changeset
    end
  end

  defp guard(changeset, resource, id_attribute, label, quantity) do
    case Changeset.get_attribute(changeset, id_attribute) do
      nil ->
        changeset

      id ->
        current = current_stock(resource, id)

        if D.compare(D.add(current, quantity), D.new(0)) == :lt do
          Changeset.add_error(changeset,
            field: :quantity,
            message:
              "Stock insuficiente: no se puede dejar el stock del #{label} en negativo " <>
                "(disponible: #{format(current)}, ajuste: #{format(quantity)}).",
            vars: %{
              label: label,
              available: format(current),
              quantity: format(quantity)
            }
          )
        else
          changeset
        end
    end
  end

  defp current_stock(resource, id) do
    resource
    |> Ash.get!(id, authorize?: false)
    |> Ash.load!(:current_stock, authorize?: false)
    |> Map.fetch!(:current_stock)
    |> to_decimal()
  end

  defp to_decimal(nil), do: D.new(0)
  defp to_decimal(%D{} = value), do: value
  defp to_decimal(value) when is_integer(value), do: D.new(value)
  defp to_decimal(value) when is_float(value), do: D.from_float(value)
  defp to_decimal(value) when is_binary(value), do: D.new(value)

  defp format(value), do: value |> to_decimal() |> D.to_string(:normal)
end
