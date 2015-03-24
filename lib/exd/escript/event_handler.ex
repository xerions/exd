defmodule Exd.Script.Subscription.Handler do
  def subscription_event(changset, event) do
    :erlang.group_leader(Process.whereis(:user), self)
    IO.inspect({event, changset.changes})
  end
  def event(event) do
    :erlang.group_leader(Process.whereis(:user), self)
    IO.puts("event: #{event}")
  end
end
