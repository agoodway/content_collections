ExUnit.start()

Path.expand("support/*.exs", __DIR__)
|> Path.wildcard()
|> Enum.each(&Code.require_file/1)
