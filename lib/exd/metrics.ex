defmodule Exd.Metrics do
  @default_time 1000

  def subscribe(api) do
    for {reporter, _} <- :exometer_report.list_reporters do
      tags = [resource: {:from_name, 2},
              method: {:from_name, 4}]
      tags_with_type = tags ++ [type: {:from_name, 5}]
      for crud <- api.__apix__(:methods) do
        for result <- [:ok, :error, :db_not_available_error] do
          name = name(api, crud, [result, :per_sec])
          :exometer_report.subscribe(reporter, name, :one, @default_time, tags_with_type, true)
        end
        name = name(api, crud, :handle_time)
        :exometer_report.subscribe(reporter, name, :max, @default_time, tags, true)
        :exometer_report.subscribe(reporter, name, :mean, @default_time, tags, true)
      end
    end
  end

  def request(api, method, fun) do
    {time, value} = :timer.tc(fun)
    case value do
      %{errors: %{database: "not available"}} -> db_error_request(api, method)
      %{errors: _} -> error_request(api, method)
      _ -> ok_request(api, method)
    end
    handle_time(api, method, time / 1000)
    value
  end

  defp ok_request(api, method) do
    :exometer.update_or_create(name(api, method, [:ok, :per_sec]), 1, :spiral, [{:time_span, 1000}])
  end

  defp error_request(api, method) do
    :exometer.update_or_create(name(api, method, [:error, :per_sec]), 1, :spiral, [{:time_span, 1000}])
  end

  defp db_error_request(api, method) do
    :exometer.update_or_create(name(api, method, [:db_not_available_error, :per_sec]), 1, :spiral, [{:time_span, 1000}])
  end

  defp handle_time(api, method, time), do:
    :exometer.update_or_create(name(api, method, :handle_time), time, :histogram, [{:truncate, false}])

  defp name(api, method, :handle_time), do:
    [:api, "#{api.__exd_api__(:tech_name)}" |> String.to_atom, :request, "#{method}" |> String.to_atom, :handle_time]
    |> List.flatten

  defp name(api, method, name), do:
    [:api, "#{api.__exd_api__(:tech_name)}" |> String.to_atom, :requests, "#{method}" |> String.to_atom, name]
    |> List.flatten
end
