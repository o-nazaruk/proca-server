defmodule Proca.Server.Notify do
  @moduledoc """
  Server that decides what actions should be done after different events
  """
  alias Proca.Repo
  alias Proca.{Action, Supporter, Org, PublicKey, Confirm, Service, ActionPage, Campaign}
  alias Proca.Stage.Event
  alias Proca.Pipes
  import Logger

  ####################

  def created(record, opts \\ [])

  @doc """
  Notifications on creation of record
  """
  def created(org = %Org{}, _opts) do
    start_org_pipes(org)
  end

  def created(%ActionPage{} = action_page, opts) do
    updated(action_page, opts)
  end

  # confirm that has associated org
  # send it to it's owners
  def created(%Confirm{operation: :launch_page, subject_id: campaign_id} = cnf, opts) do
    case Campaign.one(id: campaign_id, preload: [:org]) do
      nil ->
        :ok

      %Campaign{org: %Org{} = org} ->
        send_confirm_by_email(cnf, org)
        Event.emit(:confirm_created, cnf, org.id, opts)
    end
  end

  # Confirm that does not have an org to be notified
  # we send it to confirm.email if exists
  # and we send it to instance org as event
  def created(%Confirm{} = cnf, opts) do
    send_confirm_by_email(cnf, nil)

    case Proca.Server.Instance.org() do
      %{id: id} -> Event.emit(:confirm_created, cnf, id, opts)
      _ -> :ok
    end
  end

  def created(_, _opts), do: :ok

  @doc """
  Notifications on update of record
  """
  def updated(record, opts \\ [])

  def updated(org = %Org{}, _opts) do
    restart_org_pipes(org)

    if org.name == Org.instance_org_name() do
      instance_org_updated(org)

      Org.all([])
      |> Enum.each(&Proca.Pipes.Supervisor.reload_child/1)
    end
  end

  def updated(%ActionPage{} = action_page, _opts) do
    action_page = Repo.preload(action_page, [:org, :campaign])
    publish_subscription_event(action_page, action_page_upserted: "$instance")

    if not is_nil(action_page.org) do
      publish_subscription_event(action_page, action_page_upserted: action_page.org.name)
    end

    :ok
  end

  def updated(%PublicKey{active: true} = key, _opts) do
    key_activated(key)
  end

  def updated(%Supporter{email_status: email_status} = supporter, opts)
      when email_status != 0 do
    supporter = Repo.preload(supporter, [:contacts])

    for c <- supporter.contacts do
      Event.emit(:email_status, supporter, c.org_id, opts)
    end
  end

  def updated(%Campaign{org_id: org_id} = campaign, opts) when is_number(org_id) do
    Event.emit(:campaign_updated, campaign, org_id, opts)
  end

  def updated(%Proca.Service.EmailTemplate{} = tmpl, opts) do
    Proca.Service.EmailTemplateDirectory.bust_cache_template(tmpl)
  end

  def updated(_, _opts), do: :ok

  @doc """
  Notifications on deletion of record
  """
  def deleted(record, opts \\ [])

  def deleted(org = %Org{}, _opts) do
    stop_org_pipes(org)
  end

  def deleted(_, _opts), do: :ok

  def multi(op, records, opts \\ [])

  def multi(op, %{action: action}, _opts)
      when op in [:add_action, :add_action_contact] do
    increment_counter(action, action.supporter)
    process_action(action)
    update_action_page_status(action)
    :ok
  end

  def multi(:key_activated, %{active_key: key}, _opts) do
    key_activated(key)
  end

  def multi(:upsert_campaign, records, opts) do
    {campaign, pages_map} = Map.pop(records, :campaign)

    updated(campaign, opts)

    Enum.each(pages_map, fn {_k, page} ->
      updated(page, opts)
    end)
  end

  def multi(:user_created_org, %{org: org}, opts) do
    created(org, opts)
  end

  def multi(:delete_action_page, result, _opts) do
    {_, page} =
      Enum.find(result, fn
        {{:action_page, _}, _} -> true
        _ -> false
      end)

    info("Deleted page #{inspect(page)}")
  end

  def multi(:delete_campaign, result, _opts) do
    {_, campaign} =
      Enum.find(result, fn
        {{:campaign, _}, _} -> true
        _ -> false
      end)

    info("Deleted campaign #{inspect(campaign)}")
  end

  ##### SIDE EFFECTS ######
  def instance_org_updated(org) do
    Proca.Server.Instance.update(org)
  end

  def key_activated(%PublicKey{active: true, org: org} = key) do
    Proca.Server.Keys.update_key(org, key)
  end

  def send_confirm_as_event(cnf, org_id) do
    Event.emit(:confirm_created, cnf, org_id)
  end

  def send_confirm_by_email(cnf = %Proca.Confirm{email: nil}, org = %Proca.Org{}) do
    recipients =
      Repo.preload(org, staffers: :user).staffers
      |> Enum.map(fn %{user: user} -> user.email end)

    cnf = Repo.preload(cnf, [:creator])
    Proca.Confirm.notify_by_email(cnf, recipients)
  end

  def send_confirm_by_email(cnf = %Proca.Confirm{email: _email}, nil) do
    Proca.Confirm.notify_by_email(cnf)
  end

  def start_org_pipes(org = %Org{}) do
    Pipes.Supervisor.start_child(org)
  end

  def restart_org_pipes(org = %Org{}) do
    Pipes.Supervisor.reload_child(org)
  end

  def stop_org_pipes(org = %Org{}) do
    Pipes.Supervisor.terminate_child(org)
  end

  defp process_action(action) do
    Proca.Server.Processing.process_async(action)
  end

  defp update_action_page_status(action) do
    Proca.ActionPage.Status.track_action(action)
  end

  defp increment_counter(
         %Action{campaign_id: cid, action_page: %{org_id: org_id}, action_type: atype},
         nil
       ) do
    Proca.Server.Stats.increment(cid, org_id, atype, nil, false)
  end

  defp increment_counter(
         %Action{campaign_id: cid, action_page: %{org_id: org_id}, action_type: atype},
         %Supporter{area: area}
       ) do
    Proca.Server.Stats.increment(cid, org_id, atype, area, true)
  end

  defp publish_subscription_event(record, routing_key) do
    Absinthe.Subscription.publish(ProcaWeb.Endpoint, record, routing_key)
  end
end
