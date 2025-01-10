defmodule InventoryService.Application do



  def start(_type, _arg) do

    children = [

    ]

    opts = [strategy: :one_for_one, name: InventoryService.Supervisor]

    Supervisor.start_link(children,opts)


  end

end
