defmodule ProcaWeb.Schema.ConfirmTypes do 
  @moduledoc """
  API form confirms

  - you can accept / reject confirm on behalf of organisation
  - you can accept / reject confirm on behalf of your user (invitation to an org team) - although you might not have a user yet
  """
  use Absinthe.Schema.Notation
  alias ProcaWeb.Resolvers
  alias ProcaWeb.Resolvers.Authorized

  input_object :confirm_input do 
    field :code, non_null(:string)
    field :email, :string 
    field :object_id, :integer
  end
 
  object :confirm_result do 
    field :status, non_null(:status)
    field :action_page, :action_page
    field :campaign, :campaign
    field :org, :org
  end
  
  object :confirm_mutations do 
    @desc "Accept a confirm on behalf of organisation."
    field :accept_org_confirm, type: non_null(:confirm_result) do 
      middleware Authorized, access: [:org, by: [:name]]

      arg :name, non_null(:string)
      arg :confirm, non_null(:confirm_input)

      resolve &ProcaWeb.Resolvers.Confirm.org_confirm/3
    end

    @desc "Reject a confirm on behalf of organisation."
    field :reject_org_confirm, type: non_null(:confirm_result) do 
      middleware Authorized, access: [:org, by: [:name]]

      arg :name, non_null(:string)
      arg :confirm, non_null(:confirm_input)

      resolve &ProcaWeb.Resolvers.Confirm.org_reject/3
    end

    field :request_signoff_page, type: non_null(:status) do
      middleware Authorized, access: [:action_page, by: [:name]]

      arg :name, non_null(:string) 

      resolve &ProcaWeb.Resolvers.ActionPage.request_signoff_page/3
    end
  end

end
