defmodule Proca.Staffer do
  @moduledoc """
  Join table between Org and User. Means that user has a role/some permissions in an Org.
  """
  use Ecto.Schema
  import Ecto.Changeset
  use Proca.Schema, module: __MODULE__
  alias Proca.Repo
  alias Proca.Users.User
  alias Proca.Staffer
  import Ecto.Query, only: [from: 2, join: 4, where: 3, preload: 2, distinct: 2]

  schema "staffers" do
    field :perms, :integer
    field :last_signin_at, :utc_datetime
    belongs_to :org, Proca.Org
    belongs_to :user, Proca.Users.User

    timestamps()
  end

  @doc false
  def changeset(staffer, attrs) do
    staffer
    |> cast(attrs, [:perms, :last_signin_at, :org_id, :user_id])
    |> validate_required([:perms])
    |> unique_constraint([:org_id, :user_id])
  end

  def change_perms(staffer, perms_changer) do
    change(staffer, perms: perms_changer.(staffer.perms))
  end

  # deprecated
  def build_for_user(%User{id: id}, org_id, perms) when is_integer(org_id) do
    %Staffer{}
    |> change(org_id: org_id, user_id: id, perms: Proca.Permission.add(0, perms))
  end

  def create(st, [{assoc, record} | kw]) when assoc in [:user, :org] do 
    put_assoc(st, assoc, record)
    |> create(kw)
  end

  def create(st, [{:role, role} | kw]), do: create(st, [{:perms, Staffer.Role.permissions(role)} | kw])
  def create(st, [{:perms, perms} | kw]) do 
    change(st, perms: Proca.Permission.add(0, perms))
    |> create(kw)
  end

  def all(q, [:preload | kw]), do: preload(q, [:user, :org]) |> all(kw)

  def all(q, [{:org, org} | kw]), do: where(q, [s], s.org_id == ^org.id)  |> all(kw)
  def all(q, [{:user, user} | kw]), do: where(q, [s], s.user_id == ^user.id) |> all(kw)

  def for_user_in_org(%User{id: id}, org_name) when is_bitstring(org_name) do
    from(s in Staffer,
      join: o in assoc(s, :org),
      where: s.user_id == ^id and o.name == ^org_name,
      preload: [org: o]
    )
    |> Repo.one()
  end

  def for_user_in_org(%User{id: id}, org_id) when is_integer(org_id) do
    from(s in Staffer,
      join: o in assoc(s, :org),
      where: s.user_id == ^id and o.id == ^org_id,
      preload: [org: o]
    )
    |> Repo.one()
  end

  def for_user(%User{id: id}) do
    from(s in Staffer,
      join: o in assoc(s, :org),
      where: s.user_id == ^id,
      order_by: [desc: :last_signin_at],
      preload: [org: o],
      limit: 1
    )
    |> Repo.one()
  end

  def get_by_org(org_id, preload \\ [:user]) when is_integer(org_id) do
    Proca.Repo.all(from s in Proca.Staffer, where: s.org_id == ^org_id, preload: ^preload)
  end

  def not_in_org(org_id) do
    from(u in User,
      left_join: st in Staffer,
      on: u.id == st.user_id and st.org_id == ^org_id,
      where: is_nil(st.id)
    )
    |> distinct(true)
    |> Repo.all()
  end

end
