ExUnit.start()

import Exd.Model

model Test do
  schema "test" do
    field :name
    field :data
  end
end

defmodule TestHelper, do: :ok
