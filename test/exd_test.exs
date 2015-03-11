import Exd.Model

require Test
model_add UpdateTest, to: Test do
  schema do
    field :value, :float, default: 0.0
  end
end

defmodule ExdTest do
  use ExUnit.Case

  test "model_compiled" do
    Exd.Model.compile(Test, [])
    assert %{name: _} = %Test{}
    assert_raise MatchError, fn -> %{value: _} = %Test{} end
    Exd.Model.compile(Test, [UpdateTest])
    assert %{value: _} = %Test{}
  end
end
