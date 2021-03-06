defmodule Mix.Tasks.Hex.Info do
  use Mix.Task

  @shortdoc "Prints Hex information"

  @moduledoc """
  Prints Hex package or system information.

  `mix hex.info [PACKAGE [VERSION]]`

  If `package` is not given, print system information. This includes when
  registry was last updated and current system version.

  If `package` is given, print information about the package. This includes all
  released versions and package metadata.

  If `package` and `version` is given print release information. This includes
  remote Git URL and Git ref, and all package dependencies.
  """

  def run(args) do
    {_opts, args, _} = OptionParser.parse(args)
    Hex.start

    case args do
      [] -> general()
      [package] -> package(package)
      [package, version] -> release(package, version)
      _ ->
        Mix.raise "Invalid arguments, expected: mix hex.info [PACKAGE [VERSION]]"
    end
  end

  defp general() do
    Hex.Shell.info "Hex:    v#{Hex.version}"
    Hex.Shell.info "Elixir: v#{System.version}"
    Hex.Shell.info "ERTS:   v#{:erlang.system_info(:version)}"
    Hex.Shell.info ""
    Hex.Shell.info "Built with: Elixir v#{Hex.elixir_version} & ERTS v#{Hex.erts_version}"
    Hex.Shell.info ""

    # Make sure to fetch registry after showing Hex version. Issues with the
    # registry should not prevent printing the version.
    Hex.Utils.ensure_registry(cache: false)
    path            = Hex.Registry.path()
    stat            = File.stat!(path)
    compressed_stat = File.stat!(path <> ".gz")
    size            = stat.size |> div(1024)
    compressed_size = compressed_stat.size |> div(1024)
    {packages, releases} = Hex.Registry.stat()

    Hex.Shell.info "Registry file available (last updated: #{pretty_date(stat.mtime)})"
    Hex.Shell.info "Size: #{size}kB (compressed #{compressed_size}kb)"
    Hex.Shell.info "Packages #: #{packages}"
    Hex.Shell.info "Versions #: #{releases}"
  end

  defp package(package) do
    Hex.Utils.ensure_registry(cache: false)

    case Hex.API.Package.get(package) do
      {code, body} when code in 200..299 ->
        pretty_package(body)
      {404, _} ->
        Hex.Shell.error "No package with name #{package}"
      {code, body} ->
        Hex.Shell.error "Failed to retrieve package information"
        Hex.Utils.print_error_result(code, body)
    end
  end

  defp release(package, version) do
    Hex.Utils.ensure_registry(cache: false)

    case Hex.API.Release.get(package, version) do
      {code, body} when code in 200..299 ->
        pretty_release(package, body)
      {404, _} ->
        Hex.Shell.error "No release with name #{package} v#{version}"
      {code, body} ->
        Hex.Shell.error "Failed to retrieve release information"
        Hex.Utils.print_error_result(code, body)
    end
  end

  defp pretty_package(package) do
    Hex.Shell.info package["name"]
    pretty_package_string(package["name"], package["releases"])
    Hex.Shell.info "  Releases: " <> Enum.map_join(package["releases"], ", ", &(&1["version"]))
    Hex.Shell.info ""
    pretty_meta(package["meta"])
  end

  defp pretty_meta(meta) do
    pretty_list(meta, "contributors")
    pretty_list(meta, "maintainers")
    pretty_list(meta, "licenses")
    pretty_dict(meta, "links")

    if descr = meta["description"] do
      Hex.Shell.info ""
      Hex.Shell.info descr
    end
  end

  defp pretty_release(package, release) do
    version = release["version"]
    Hex.Shell.info package <> " v" <> version
    pretty_package_string(package, release)

    if release["has_docs"] do
      # TODO: Only print this URL if we use the default API URL
      Hex.Shell.info "  Documentation at: #{Hex.Utils.hexdocs_url(package, version)}"
    end

    if release["requirements"] do
      Hex.Shell.info "  Dependencies:"
      Enum.each(release["requirements"], fn {name, req} ->
        optional = if req["optional"], do: " (optional)"
        Hex.Shell.info "    #{name}: #{req["requirement"]}#{optional}"
      end)
    end
  end

  defp pretty_package_string(name, [latest_release | _]) do
    pretty_package_string(name, latest_release)
  end

  defp pretty_package_string(name, release) do
    app_name = release["meta"]["app"] || name
    {:ok, version} = Version.parse(release["version"])
    snippet  = mix_snippet_version(version)

    Hex.Shell.info "Config:"
    if name == app_name do
      Hex.Shell.info "{:#{name}, \"#{snippet}\"}"
    else
      Hex.Shell.info "{:#{app_name}, \"#{snippet}\", hex: :#{name}}"
    end
  end

  defp mix_snippet_version(%Version{major: 0, minor: minor, patch: patch, pre: []}),
    do: "~> 0.#{minor}.#{patch}"
  defp mix_snippet_version(%Version{major: major, minor: minor, pre: []}),
    do: "~> #{major}.#{minor}"
  defp mix_snippet_version(%Version{major: major, minor: minor, patch: patch, pre: pre}),
    do: "~> #{major}.#{minor}.#{patch}#{pre_snippet(pre)}"

  defp pre_snippet([]), do: ""
  defp pre_snippet(pre) do
    "-" <>
      Enum.map_join(pre, ".", fn
        int when is_integer(int) -> Integer.to_string(int)
        string when is_binary(string) -> string
      end)
  end

  defp pretty_list(meta, name) do
    if (list = meta[name]) && list != [] do
      Hex.Shell.info("  #{String.capitalize(name)}: " <> Enum.join(list, ", "))
    end
  end

  defp pretty_dict(meta, name, title \\ nil) do
    title = title || String.capitalize(name)

    if (dict = meta[name]) && dict != [] do
      Hex.Shell.info "  #{title}:"
      Enum.each(dict, fn {name, url} ->
        Hex.Shell.info "    #{name}: #{url}"
      end)
    end
  end

  defp pretty_date({{year, month, day}, {hour, min, sec}}) do
    "#{pad(year, 4)}-#{pad(month, 2)}-#{pad(day, 2)} " <>
    "#{pad(hour, 2)}:#{pad(min, 2)}:#{pad(sec, 2)}"
  end

  defp pad(int, padding) do
    str = to_string(int)
    padding = max(padding-byte_size(str), 0)
    do_pad(str, padding)
  end

  defp do_pad(str, 0), do: str
  defp do_pad(str, n), do: do_pad("0" <> str, n-1)
end
