defmodule ContentCollections.Loaders.FilesystemTest do
  use ExUnit.Case, async: true

  alias ContentCollections.Loaders.Filesystem
  alias ContentCollections.TestSupport.FakeParser

  test "validate_opts/1 requires a string path" do
    assert {:error, "Path option is required"} = Filesystem.validate_opts([])
    assert {:error, "Path option must be a string"} = Filesystem.validate_opts(path: 123)
    assert :ok = Filesystem.validate_opts(path: "**/*.md")
  end

  test "load/1 loads markdown files and normalizes metadata" do
    with_tmp_dir(fn tmp_dir ->
      file = Path.join(tmp_dir, "post.md")

      content = """
      ---
      title: Hello
      date: 2024-02-03
      tags: elixir, phoenix
      published: "true"
      draft: "false"
      custom_key: 123
      ---
      # Body
      """

      File.write!(file, content)

      assert {:ok, [entry]} = Filesystem.load(path: "*.md", base_path: tmp_dir)
      assert entry.slug == "post"
      assert entry.id == "post.md"
      assert entry.content == "# Body\n"
      assert entry.metadata.title == "Hello"
      assert entry.metadata.date == ~D[2024-02-03]
      assert entry.metadata.tags == ["elixir", "phoenix"]
      assert entry.metadata.published == true
      assert entry.metadata.draft == false
      assert entry.metadata.custom_key == 123
    end)
  end

  test "load/1 uses metadata id when provided" do
    with_tmp_dir(fn tmp_dir ->
      file = Path.join(tmp_dir, "post.md")

      File.write!(
        file,
        "---\nid: custom-id\n---\nbody"
      )

      assert {:ok, [entry]} = Filesystem.load(path: "*.md", base_path: tmp_dir)
      assert entry.id == "custom-id"
    end)
  end

  test "load/1 aggregates failed files" do
    with_tmp_dir(fn tmp_dir ->
      File.write!(Path.join(tmp_dir, "good.md"), "ok")
      File.write!(Path.join(tmp_dir, "bad.md"), "parse-error")

      assert {:error, {:failed_files, errors}} =
               Filesystem.load(path: "*.md", base_path: tmp_dir, parser: FakeParser)

      assert length(errors) == 1
      assert [{:error, {failed_file, :parse_error}}] = errors
      assert String.ends_with?(failed_file, "bad.md")
    end)
  end

  test "load/1 supports parser tuple format" do
    with_tmp_dir(fn tmp_dir ->
      File.write!(Path.join(tmp_dir, "post.md"), "body")

      assert {:ok, [entry]} =
               Filesystem.load(path: "*.md", base_path: tmp_dir, parser: {FakeParser, [x: 1]})

      assert entry.metadata.title == "From parser"
      assert entry.content == "body"
    end)
  end

  defp with_tmp_dir(fun) do
    unique = System.unique_integer([:positive, :monotonic])
    tmp_dir = Path.join(System.tmp_dir!(), "content_collections_fs_#{unique}")
    File.mkdir_p!(tmp_dir)

    try do
      fun.(tmp_dir)
    after
      File.rm_rf!(tmp_dir)
    end
  end
end
