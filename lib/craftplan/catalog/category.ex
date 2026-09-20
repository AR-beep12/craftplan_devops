defmodule Craftplan.Catalog.Category do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "catalog_categories"
    repo Craftplan.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      argument :name, :string, allow_nil?: false

      change set_attribute(:name, arg(:name))
      change Craftplan.Catalog.Category.Changes.NormalizeName
    end

    update :update do
      primary? true
      accept [:name, :active]
    end
  end

  policies do
    bypass expr(^actor(:role) == :admin) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) in [:staff, :admin])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 2, max_length: 100
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
      description "URL-friendly slug derived from name"
    end

    attribute :active, :boolean do
      allow_nil? false
      public? true
      default true
      description "Si la categoría está activa y se muestra en el formulario de productos"
    end

    timestamps()
  end

  relationships do
    has_many :products, Craftplan.Catalog.Product do
      destination_attribute :category_id
    end
  end

  identities do
    identity :name, [:name]
    identity :slug, [:slug]
  end
end

defmodule Craftplan.Catalog.Category.Changes.NormalizeName do
  @moduledoc false
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :name) do
      nil ->
        changeset

      name when is_binary(name) ->
        slug =
          name
          |> String.downcase()
          |> String.normalize(:nfd)
          |> String.replace(~r/[^a-z0-9\s-]/u, "")
          |> String.replace(~r/\s+/, "-")
          |> String.trim("-")

        changeset
        |> Ash.Changeset.change_attribute(:name, String.trim(name))
        |> Ash.Changeset.change_attribute(:slug, slug)
    end
  end
end
