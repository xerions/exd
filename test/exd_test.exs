
import Ecto.Query

Code.require_file "test/db/db_helper.exs"
Code.require_file "test/test_repo.exs"

defmodule ExdTest do
  use ExUnit.Case

  {adapter, url} = case Mix.env do
                     :pg ->
                       {Ecto.Adapters.Postgres, "ecto://postgres:postgres@localhost/exd_test"}
                     _ ->
                       {Ecto.Adapters.MySQL, "ecto://root@localhost/exd_test"}
                   end

  Application.put_env(:exd,
                      Test.Repo,
                      adapter: adapter,
                      url: url,
                      size: 1,
                      max_overflow: 0)

  test "Exd migration tests" do
    Exd.Test.DbHelper.drop_db
    Exd.Test.DbHelper.create_db

    Test.Repo.start_link
    result = Exd.Model.compile_migrate_model(Test.Repo, TestTable, [])
    assert result == :ok

    # test system table
    query = from table in Exd.Schema.SystemTable, where: table.tablename == "test_table", select: table
    [query_result] = Test.Repo.all(query)
    assert query_result.metainfo == "field_1:string,field_2:integer,"
    assert query_result.tablename == "test_table"

    # test second migration
    result = Exd.Model.compile_migrate_model(Test.Repo, TestTable, [])
    assert result == :nothing_migrate

    Test.Repo.stop
    Exd.Test.DbHelper.drop_db
>>>>>>> exd: Support for migrations and eScript
  end
end
