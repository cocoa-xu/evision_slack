defmodule EvisionSlack.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Kino.SmartCell.register(EvisionSlack.ImageCell)

    children = [
      {Finch, name: EvisionSlack.Finch}
    ]
    opts = [strategy: :one_for_one, name: EvisionSlack.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
