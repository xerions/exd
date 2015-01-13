Exd
===

Main goals

* handling data patterns in consistent way
* consistent way to expose the models to CLI/API/WEB
* easy way of schema/data migration
* integration with erlang

Exd - library based on [ecto](https://github.com/elixir-lang/ecto) for productive boost in data handling for backend systems. There are some different goals, make it possible to quick bootstrap and migrate, allow configuration-based change of models ( customizing ). This library tries to explore, define and implement patterns based on ecto, that we used in erlang applications with NoSQL database and found as good practise, to get best of both world.

If some of this patterns ( like automigration ) will be usefull generally in ecto, we are ready to move and contribute it to ecto.

Easy bootstrap
--------------

    # Configuration for Repo, only for iex try taste, please use supervisor in your application
    :application.set_env(:example, Repo, [adapter: Ecto.Adapters.MySQL, database: "example", username: "root"])
    defmodule Repo, do: (use Ecto.Repo, otp_app: :example)
    Repo.start_link

    import Exd.Model

    model Weather do # is for later at now
      schema "weather" do
        field :city
        field :temp_lo, :integer
        field :temp_hi, :integer
        field :prcp,    :float, default: 0.0
      end
    end # compiles to Ecto model

    # After you start a Repo, no mix tasks, no themself written migrations
    Exd.Model.migrate(Repo, Weather)

    %Weather{city: "Berlin", temp_lo: 20, temp_hi: 25} |> Repo.insert
    Repo.all(from w in Weather, where: w.city == "Berlin")

At the moment, only initial migration supported, next migrations are WiP at the moment.

Configurable model on start
---------------------------

There is model_add construct and a function, which allows on start to define the model and with 'plugins', how should the data see. [WiP]

Data handling patterns
----------------------

There are some patterns on handling data (like inheritance, for example comment can inherit a user picture for that case, if the user changes the own picture, this specific comment will show old picture), that need to have generic handlers. [WiP]

Expose ecto to erlang application
---------------------------------

As the ecto interface is based heavily on macros, and not directly invokable in erlang, there should exists reach erlang API to allow to handle and manipulate Ecto model from erlang application. [WiP]

Model-driven development
------------------------

For different APIs, there should be an adaptor, which allows to define the model API in consistent way. There are 2 examples at the moment:

* json-rpc - all data manipulation should be consistent with different models and the code should be written only once.
* CLI - it should be possible to query with CLI the application data (example can be 'my_script select user where id == 1' and it should be possible for every model in consistent way [WiP])
