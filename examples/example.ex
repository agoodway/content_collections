defmodule ContentCollections.Example do
  @moduledoc """
  Example usage of ContentCollections.

  This module demonstrates how to use ContentCollections in your application.
  It loads markdown files from `priv/content/examples/`.
  """

  use ContentCollections,
    loader: {ContentCollections.Loaders.Filesystem, path: "priv/content/examples/**/*.md"},
    compile_time: false,
    renderer:
      {ContentCollections.Renderers.MDEx,
       extension: [
         table: true,
         strikethrough: true,
         tasklist: true,
         autolink: true
       ]}

  @doc """
  Get all published posts.
  """
  def published do
    filter(fn entry ->
      Map.get(entry.metadata, :published, false)
    end)
  end

  @doc """
  Get posts by tag.
  """
  def by_tag(tag) do
    filter(fn entry ->
      tags = Map.get(entry.metadata, :tags, [])
      tag in tags
    end)
  end

  @doc """
  Get the most recent posts.
  """
  def recent(limit \\ 5) do
    all()
    |> Enum.sort_by(& &1.metadata[:date], {:desc, Date})
    |> Enum.take(limit)
  end

  @doc """
  Get a paginated list of published posts.
  """
  def published_page(page \\ 1, per_page \\ 10) do
    filter(
      fn entry ->
        Map.get(entry.metadata, :published, false)
      end,
      page: page,
      per_page: per_page
    )
  end
end
