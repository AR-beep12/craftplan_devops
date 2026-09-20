defmodule Craftplan.CRM.Customer do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.CRM,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  require Ash.Resource.Preparation.Builtins

  json_api do
    type "customer"

    routes do
      base("/customers")
      get(:read)
      index :list
      post(:create)
      patch(:update)
      delete(:destroy)
    end
  end

  graphql do
    type :customer

    queries do
      get(:get_customer, :read)
      list(:list_customers, :list)
    end

    mutations do
      create :create_customer, :create
      update :update_customer, :update
      destroy :destroy_customer, :destroy
    end
  end

  postgres do
    table "crm_customers"
    repo Craftplan.Repo
  end

  actions do
    default_accept :*
    defaults [:read, :create, :update]

    destroy :destroy do
      require_atomic? false
      require Ash.Query
      change fn changeset, _ ->
        customer = changeset.data

        active_statuses = [:pending, :in_progress]

        active_orders =
          case Craftplan.Orders.Order
               |> Ash.Query.filter(expr(customer_id == ^customer.id and status in ^active_statuses))
               |> Ash.read(authorize?: false) do
            {:ok, orders} -> length(orders)
            {:error, _} -> 0
          end

        if active_orders > 0 do
          Ash.Changeset.add_error(
            changeset,
            field: :base,
            message:
              "No se puede eliminar el cliente: tiene #{active_orders} pedido(s) pendiente(s) o en progreso."
          )
        else
          changeset
        end
      end
    end

    # Narrow read used by checkout
    read :get_by_email do
      get? true
      argument :email, :string, allow_nil?: false
      filter expr(email == ^arg(:email))
    end

    read :list do
      prepare build(sort: :first_name)

      pagination do
        required? false
        offset? true
        keyset? true
        countable true
      end
    end

    read :keyset do
      prepare build(sort: :first_name)
      pagination keyset?: true
    end
  end

  policies do
    # API key scope check
    policy always() do
      authorize_if {Craftplan.Accounts.Checks.ApiScopeCheck, []}
    end

    # Admin can do anything
    bypass expr(^actor(:role) == :admin) do
      authorize_if always()
    end

    # Allow only targeted email lookup publicly
    policy action(:get_by_email) do
      authorize_if always()
    end

    # Allow public create/update (checkout address upsert). Consider narrowing in future.
    policy action_type([:create, :update]) do
      authorize_if always()
    end

    # Other reads/destroys restricted to staff/admin
    policy action_type(:read) do
      authorize_if expr(^actor(:role) in [:staff, :admin])
    end

    policy action_type(:destroy) do
      authorize_if expr(^actor(:role) in [:staff, :admin])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :reference, :string do
      writable? false

      default fn ->
        random_str =
          12
          |> :crypto.strong_rand_bytes()
          |> Base.encode32(padding: false, case: :upper)
          |> String.slice(0..11)

        "CUS_#{random_str}"
      end

      allow_nil? false
      generated? true

      constraints match: ~r/^CUS_[A-Z0-9]{12}$/,
                  allow_empty?: false
    end

    attribute :first_name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, match: ~r/^[\p{L}\p{N}\w\s\-\.&・（）「」]+$/u
    end

    attribute :last_name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, match: ~r/^[\p{L}\p{N}\w\s\-\.&・（）「」]+$/u
    end

    attribute :email, :string do
      allow_nil? true
      public? true
      constraints match: ~r/@/
    end

    attribute :phone, :string do
      allow_nil? true
      public? true
      constraints max_length: 15
    end

    timestamps()
  end

  relationships do
    has_many :orders, Craftplan.Orders.Order
  end

  calculations do
    calculate :full_name, :string, expr(first_name <> " " <> last_name)
  end

  aggregates do
    count :total_orders, :orders

    sum :total_orders_value, [:orders, :items], :cost do
    end
  end

  identities do
    identity :phone, [:phone], message: "Este teléfono ya está registrado"
    identity :email, [:email]
    identity :reference, [:reference]
  end
end
