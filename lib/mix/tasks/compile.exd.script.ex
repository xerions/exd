defmodule Mix.Tasks.Compile.Exd.Script do
	use Mix.Task

	@shortdoc "Generate Exd escript"

	def run(_args) do
		Mix.Task.run(:'escript.build', [])
	end

end
