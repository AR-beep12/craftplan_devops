defmodule Craftplan.Orders.Order.Types.Status do
  @moduledoc false
  use Ash.Type.Enum,
    values: [
      :pending,
      :in_progress,
      :completed,
      :cancelled
    ]
end
