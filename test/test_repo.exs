import Exd.Model, only: :macros
import Exd.Model.Api, only: :macros

defmodule TestDbHelper do
	def get_adapter do
		case Mix.env do
			:pg ->
				Ecto.Adapters.Postgres
			_ ->
				Ecto.Adapters.MySQL
		end
	end
end

defmodule Test.Repo do
  use Ecto.Repo,
  otp_app: :exd,
	# TODO remove it
	adapter: TestDbHelper.get_adapter
end

model TestTable do
  schema "test_table" do
    field :field_1
    field :field_2, :integer
  end
end

gen_api TestTable, Test.Repo
