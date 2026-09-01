defmodule Craftplan.CRM.Address do
  @moduledoc false
  use Ash.Resource,
    data_layer: :embedded,
    embed_nil_values?: false

  actions do
    default_accept :*
    defaults [:read, :create, :update, :destroy]
  end

end
