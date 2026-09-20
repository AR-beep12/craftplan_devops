defmodule Craftplan.Repo.Migrations.UpdateOrderStatuses do
  use Ecto.Migration

  def up do
    execute("""
      UPDATE orders_orders
      SET status = CASE status
        WHEN 'unconfirmed' THEN 'pending'
        WHEN 'confirmed' THEN 'in_progress'
        WHEN 'ready' THEN 'completed'
        WHEN 'delivered' THEN 'completed'
        ELSE status
      END
    """)
  end

  def down do
    execute("""
      UPDATE orders_orders
      SET status = CASE status
        WHEN 'pending' THEN 'unconfirmed'
        WHEN 'in_progress' THEN 'confirmed'
        WHEN 'completed' THEN 'delivered'
        ELSE status
      END
    """)
  end
end
