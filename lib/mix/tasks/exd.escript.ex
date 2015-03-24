defmodule Mix.Tasks.Exd.Escript do
	use Mix.Task

	@shortdoc "Generate Exd escript"
  @spec run(OptionParser.argv) :: :ok | :noop
  def run(args) do
    Mix.Project.get!
    project = Mix.Project.config
    language = Keyword.get(project, :language, :elixir)

    {opts, _, _} = OptionParser.parse(args, switches: [force: :boolean])
    should_consolidate = Keyword.get(project, :consolidate_protocols, language == :elixir)
    if should_consolidate, do: Mix.Task.run("compile.protocols", [])

    app = project[:app]
    escript_opts = [main_module: Exd.Escript.Main, name: to_string(app), app: app]
    Exscript.escriptize(project, language, escript_opts, opts[:force], should_consolidate)
  end
end
