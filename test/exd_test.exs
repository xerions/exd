
import Ecto.Query

Code.require_file "test/db/db_helper.exs"
Code.require_file "test/test_repo.exs"

defmodule ExdTest do
  use ExUnit.Case

  test "Exd migration tests" do
    result = Exd.Model.compile_migrate(EctoIt.Repo, TestTable, [])
    assert result == :ok

    # test system table
    query = from table in Exd.Schema.SystemTable, where: table.tablename == "test_table", select: table
    [query_result] = EctoIt.Repo.all(query)
    assert query_result.metainfo == "field_1:string,field_2:integer,"
    assert query_result.tablename == "test_table"

    # test second migration
    result = Exd.Model.compile_migrate(Test.Repo, TestTable, [])
    assert result == :nothing_migrate

    Test.Repo.stop
    Exd.Test.DbHelper.drop_db
  end
end
