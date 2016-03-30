defmodule Exd.Metrics do

  import Ecto.Query

  @default_entries  [:exd]

  @object_counter   {:function,
                     Exd.Metrics,
                     :count_objects,
                     nil,
                     :proplist,
                     [:value]}

  @counter          {:counter, []}

  @histogram_60000  {:histogram,
                     [slot_period: 100,
                      time_span: 60000]}

  @object_metrics   [## just object metrics for each api
                     {:object, [
                      {:counter, @object_counter}]}]

  @request_metrics  [## just request metrics for each api
                     {:request, :total, [
                      {:gauge, @histogram_60000},
                      {:counter, @counter}]},
                     {:request, :get, [
                      {:gauge, @histogram_60000},
                      {:counter, @counter}]},
                     {:request, :put, [
                      {:gauge, @histogram_60000},
                      {:counter, @counter}]},
                     {:request, :post, [
                      {:gauge, @histogram_60000},
                      {:counter, @counter}]},
                     {:request, :delete, [
                      {:gauge, @histogram_60000},
                      {:counter, @counter}]}]


  def init_metrics() do
    metrics = Application.get_env(:exd, :metrics, [])
    enabled_metrics = Keyword.get(metrics, :enabled, [])
    # here some basic request metrics are created
    for status <- [:total, :success, :error, :db_not_available] do
      final_total_counter_id = @default_entries ++ [:request, :total, :total, status, :counter]
      final_total_gauge_id = @default_entries ++ [:request, :total, :total, status, :gauge]
      if Enum.member?(enabled_metrics, :request) do
        {:counter, counter_opts} = @counter
        {:histogram, histogram_opts} = @histogram_60000
        :exometer.new(final_total_counter_id, :counter, counter_opts)
        :exometer.update_or_create(final_total_gauge_id, 0, :histogram, histogram_opts)
      end
    end
  end

  def init_metrics(api) do
    metrics = Application.get_env(:exd, :metrics, [])
    enabled_metrics = Keyword.get(metrics, :enabled, [])
    if Enum.member?(enabled_metrics, :object), do:
      create_object_metrics(api)
    if Enum.member?(enabled_metrics, :request), do:
      create_request_metrics(api)
  end

  defp create_object_metrics(api) do
    [{unit_type, function_args}] = @object_metrics[:object]
    api_name = "#{api.__exd_api__(:tech_name)}" |> String.to_atom
    final_id = @default_entries ++ [:object, api_name, unit_type]
    :exometer.new(final_id, :erlang.setelement(4, function_args, [api]))
  end

  def count_objects(api) do
    model = api.__exd_api__(:model)
    repo = api.__exd_api__(:repo)
    value = repo.one(from u in model, select: count(u.id))
    [value: value]
  end

  defp create_request_metrics(api) do
    object_name = "#{api.__exd_api__(:tech_name)}" |> String.to_atom
    for {metric_name, metric_type, units} <- @request_metrics do
      for {unit_type, {exo_type, exo_type_opts}} <- units do
        for status <- [:total, :success, :error, :db_not_available] do
          final_id = @default_entries ++ [metric_name, metric_type, object_name, status, unit_type]
          :exometer.update_or_create(final_id, 0, exo_type, exo_type_opts)
        end
      end
    end
  end

  def request(api, method, fun) do
    # time is given in microseconds
    {time, value} = :timer.tc(fun)
    case value do
      %{errors: %{database: "not available"}} ->
                           request(:db_not_available, api, method, time / 1000)
      %{errors: _}      -> request(:error, api, method, time / 1000)
      _success_request  -> request(:success, api, method, time / 1000)
    end
    value
  end

  defp request(status, api, method, time) do
    api_name = "#{api.__exd_api__(:tech_name)}" |> String.to_atom
    # first update the request counters per api and totally
    :exometer.update(request_id(status, api_name, method, :counter), 1)
    :exometer.update(request_id(status, api_name, :total, :counter), 1)
    :exometer.update(request_id(:total, api_name, :total, :counter), 1)
    :exometer.update(request_id(status, :total, :total, :counter), 1)
    :exometer.update(request_id(:total, :total, :total, :counter), 1)

    # then update the request handle time histograms
    :exometer.update(request_id(status, api_name, method, :gauge), time)
    :exometer.update(request_id(status, api_name, :total, :gauge), time)
    :exometer.update(request_id(:total, api_name, :total, :gauge), time)
    :exometer.update(request_id(status, :total, :total, :gauge), time)
    :exometer.update(request_id(:total, :total, :total, :gauge), time)
  end

  defp request_id(status, api_name, request_type, unit_type), do:
    @default_entries ++ [:request, request_type, api_name, status, unit_type]

end
