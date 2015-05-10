import Exd.Model, only: :macros
import Exd.Model.Api, only: :macros

model TestTable do
  schema "test_table" do
    field :field_1
    field :field_2, :integer
  end
end
