defmodule Hex.MixTaskTest do
  use HexTest.Case
  @moduletag :integration

  defmodule Simple do
    def project do
      [ app: :simple,
        version: "0.1.0",
        deps: [ {:ecto, "0.2.0"} ] ]
    end
  end

  defmodule SimpleOld do
    def project do
      [ app: :simple,
        version: "0.1.0",
        deps: [ {:ecto, "~> 0.2.1"} ] ]
    end
  end

  defmodule Override do
    def project do
      [ app: :override,
        version: "0.1.0",
        deps: [ {:ecto, "0.2.0"},
                {:ex_doc, "~> 0.1.0", override: true}] ]
    end
  end

  defmodule NonHexDep do
    def project do
      [ app: :non_hex_dep,
        version: "0.1.0",
        deps: [ {:has_hex_dep, path: fixture_path("has_hex_dep")} ] ]
    end
  end

  defmodule EctoPathDep do
    def project do
      [ app: :ecto_path_dep,
        version: "0.1.0",
        deps: [ {:postgrex, ">= 0.0.0"},
                {:ecto, path: fixture_path("ecto")} ] ]
    end
  end

  defmodule OverrideWithPath do
    def project do
      [ app: :override_with_path,
        version: "0.1.0",
        deps: [ {:postgrex, ">= 0.0.0"},
                {:ex_doc, path: fixture_path("ex_doc"), override: true}] ]
    end
  end

  defmodule OverrideTwoLevelsWithPath do
    def project do
      [ app: :override_two_levels_with_path,
        version: "0.1.0",
        deps: [ {:phoenix, ">= 0.0.0"},
                {:ex_doc, path: fixture_path("ex_doc"), override: true}] ]
    end
  end

  defmodule OverrideWithPathParent do
    def project do
      [ app: :override_with_path_parent,
        version: "0.1.0",
        deps: [ {:override_with_path, path: fixture_path("override_with_path")} ] ]
    end
  end

  defmodule Optional do
    def project do
      [ app: :optional,
        version: "0.1.0",
        deps: [ {:only_doc, ">= 0.0.0"} ] ]
    end
  end

  defmodule WithOptional do
    def project do
      [ app: :with_optional,
        version: "0.1.0",
        deps: [ {:only_doc, ">= 0.0.0"},
                {:ex_doc, "0.0.1"} ] ]
    end
  end

  defmodule WithPackageName do
    def project do
      [ app: :with_package_name,
        version: "0.1.0",
        deps: [ {:app_name, ">= 0.0.0", hex: :package_name} ] ]
    end
  end

  defmodule WithDependName do
    def project do
      [ app: :with_depend_name,
        version: "0.1.0",
        deps: [ {:depend_name, ">= 0.0.0"} ] ]
    end
  end

  test "deps.get" do
    Mix.Project.push Simple

    in_tmp fn ->
      Hex.State.put(:home, System.cwd!)
      Mix.Task.run "deps.get"

      assert_received {:mix_shell, :info, ["* Getting ecto (Hex package)"]}
      assert_received {:mix_shell, :info, ["* Getting postgrex (Hex package)"]}
      assert_received {:mix_shell, :info, ["* Getting ex_doc (Hex package)"]}

      Mix.Task.run "deps.compile"
      Mix.Task.run "deps"

      assert_received {:mix_shell, :info, ["* ecto 0.2.0 (Hex package)"]}
      assert_received {:mix_shell, :info, ["  locked at 0.2.0 (ecto)"]}
      assert_received {:mix_shell, :info, ["  ok"]}

      assert_received {:mix_shell, :info, ["* postgrex 0.2.0 (Hex package)"]}
      assert_received {:mix_shell, :info, ["  locked at 0.2.0 (postgrex)"]}
      assert_received {:mix_shell, :info, ["  ok"]}

      assert_received {:mix_shell, :info, ["* ex_doc 0.0.1 (Hex package)"]}
      assert_received {:mix_shell, :info, ["  locked at 0.0.1 (ex_doc)"]}
      assert_received {:mix_shell, :info, ["  ok"]}
    end
  after
    purge [ Ecto.NoConflict.Mixfile, Postgrex.NoConflict.Mixfile,
            Ex_doc.NoConflict.Mixfile, Sample.Mixfile ]
  end

  test "deps.get with lock" do
    Mix.Project.push Simple

    in_tmp fn ->
      Hex.State.put(:home, System.cwd!)
      Mix.Task.run "deps.get"
      Mix.Task.clear

      Mix.Task.run "deps.get"
      Mix.Task.run "deps.compile"
      Mix.Task.run "deps"

      assert_received {:mix_shell, :info, ["* ecto 0.2.0 (Hex package)"]}
      assert_received {:mix_shell, :info, ["* postgrex 0.2.0 (Hex package)"]}
      assert_received {:mix_shell, :info, ["* ex_doc 0.0.1 (Hex package)"]}
    end
  after
    purge [ Ecto.NoConflict.Mixfile, Postgrex.NoConflict.Mixfile,
            Ex_doc.NoConflict.Mixfile, Sample.Mixfile ]
  end

  test "deps.update" do
    Mix.Project.push Simple

    in_tmp fn ->
      Hex.State.put(:home, System.cwd!)

      # `deps.get` to set up lock
      Mix.Task.run "deps.get"

      purge [ Ecto.NoConflict.Mixfile, Postgrex.NoConflict.Mixfile,
              Ex_doc.NoConflict.Mixfile, Sample.Mixfile ]

      Mix.ProjectStack.clear_cache
      Mix.Project.pop
      Mix.Project.push SimpleOld

      Mix.Task.run "deps.update", ["ecto"]

      assert_received {:mix_shell, :info, ["* Updating ecto (Hex package)"]}
      assert_received {:mix_shell, :info, ["* Updating postgrex (Hex package)"]}
      assert_received {:mix_shell, :info, ["* Updating ex_doc (Hex package)"]}

      Mix.Task.run "deps.compile"
      Mix.Task.run "deps"

      assert_received {:mix_shell, :info, ["* ecto 0.2.1 (Hex package)"]}
      assert_received {:mix_shell, :info, ["  locked at 0.2.1 (ecto)"]}
      assert_received {:mix_shell, :info, ["  ok"]}

      assert_received {:mix_shell, :info, ["* postgrex 0.2.1 (Hex package)"]}
      assert_received {:mix_shell, :info, ["  locked at 0.2.1 (postgrex)"]}
      assert_received {:mix_shell, :info, ["  ok"]}

      assert_received {:mix_shell, :info, ["* ex_doc 0.1.0 (Hex package)"]}
      assert_received {:mix_shell, :info, ["  locked at 0.1.0 (ex_doc)"]}
      assert_received {:mix_shell, :info, ["  ok"]}
    end
  after
    purge [ Ecto.NoConflict.Mixfile, Postgrex.NoConflict.Mixfile,
            Ex_doc.NoConflict.Mixfile, Sample.Mixfile ]
  end

  test "deps.get with override" do
    Mix.Project.push Override

    in_tmp fn ->
      Hex.State.put(:home, System.cwd!)

      Mix.Task.run "deps.get"
      Mix.Task.run "deps.compile"
      Mix.Task.run "deps"

      assert_received {:mix_shell, :info, ["* ecto 0.2.0 (Hex package)"]}
      assert_received {:mix_shell, :info, ["  locked at 0.2.0 (ecto)"]}
      assert_received {:mix_shell, :info, ["  ok"]}

      assert_received {:mix_shell, :info, ["* postgrex 0.2.1 (Hex package)"]}
      assert_received {:mix_shell, :info, ["  locked at 0.2.1 (postgrex)"]}
      assert_received {:mix_shell, :info, ["  ok"]}

      assert_received {:mix_shell, :info, ["* ex_doc 0.1.0 (Hex package)"]}
      assert_received {:mix_shell, :info, ["  locked at 0.1.0 (ex_doc)"]}
      assert_received {:mix_shell, :info, ["  ok"]}
    end
  after
    purge [ Ecto.NoConflict.Mixfile, Postgrex.NoConflict.Mixfile,
            Ex_doc.NoConflict.Mixfile, Sample.Mixfile ]
  end

  test "deps.get with non hex dependency that has hex dependency" do
    Mix.Project.push NonHexDep

    in_tmp fn ->
      Hex.State.put(:home, System.cwd!)
      Mix.Task.run "deps.get"

      assert_received {:mix_shell, :info, ["* Getting ecto (Hex package)"]}
      assert_received {:mix_shell, :info, ["* Getting postgrex (Hex package)"]}
      assert_received {:mix_shell, :info, ["* Getting ex_doc (Hex package)"]}
    end
  after
    purge [ Ecto.NoConflict.Mixfile, Postgrex.NoConflict.Mixfile,
            Ex_doc.NoConflict.Mixfile, HasHexDep.Mixfile, Sample.Mixfile ]
  end

  test "converged hex dependency considers all requirements" do
    Mix.Project.push EctoPathDep

    in_tmp fn ->
      Hex.State.put(:home, System.cwd!)
      Mix.Task.run "deps.get"

      assert_received {:mix_shell, :info, ["* Getting postgrex (Hex package)"]}

      assert %{postgrex: {:hex, :postgrex, "0.2.0"}} = Mix.Dep.Lock.read
    end
  after
    purge [ Ecto.Mixfile, Postgrex.NoConflict.Mixfile, Ex_doc.NoConflict.Mixfile ]
  end

  test "do not fetch git children of hex dependencies" do
    Mix.Project.push SimpleOld

    in_tmp fn ->
      Hex.State.put(:home, System.cwd!)
      Mix.Task.run "deps.get"

      assert_received {:mix_shell, :info, ["* Getting ecto (Hex package)"]}

      Mix.Task.run "deps"

      assert_received {:mix_shell, :info, ["* ecto (Hex package)"]}
      refute_received {:mix_shell, :info, ["* sample" <> _]}
    end
  after
    purge [ Ecto.NoConflict.Mixfile, Postgrex.NoConflict.Mixfile,
            Ex_doc.NoConflict.Mixfile, Sample.Mixfile ]
  end

  test "override hex dependency with path dependency" do
    Mix.Project.push OverrideWithPath

    in_tmp fn ->
      Hex.State.put(:home, System.cwd!)
      Mix.Task.run "deps.get"

      Mix.Task.run "deps"

      assert_received {:mix_shell, :info, ["* postgrex (Hex package)"]}
      refute_received {:mix_shell, :info, ["* ex_doc (Hex package)"]}
      assert_received {:mix_shell, :info, ["* ex_doc" <> _]}

      assert Mix.Dep.Lock.read == %{postgrex: {:hex, :postgrex, "0.2.1"}}
    end
  after
    purge [ Postgrex.NoConflict.Mixfile, ExDoc.Fixture.Mixfile ]
  end

  test "override hex dependency two levels down with path dependency" do
    Mix.Project.push OverrideTwoLevelsWithPath

    in_tmp fn ->
      Hex.State.put(:home, System.cwd!)
      Mix.Task.run "deps.get"

      Mix.Task.run "deps"

      assert_received {:mix_shell, :info, ["* phoenix (Hex package)"]}
      assert_received {:mix_shell, :info, ["* postgrex (Hex package)"]}
      refute_received {:mix_shell, :info, ["* ex_doc (Hex package)"]}
      assert_received {:mix_shell, :info, ["* ex_doc" <> _]}

      assert Mix.Dep.Lock.read == %{phoenix: {:hex, :phoenix, "0.0.1"},
                                    postgrex: {:hex, :postgrex, "0.2.1"}}
    end
  after
    purge [ Phoenix.NoConflict.Mixfile, Postgrex.NoConflict.Mixfile,
            ExDoc.Fixture.Mixfile ]
  end

  test "override hex dependency with path dependency from dependency" do
    Mix.Project.push OverrideWithPathParent

    in_tmp fn ->
      Hex.State.put(:home, System.cwd!)
      Mix.Task.run "deps.get"

      assert_received {:mix_shell, :info, ["* Getting postgrex (Hex package)"]}

      Mix.Task.run "deps"

      assert_received {:mix_shell, :info, ["* postgrex (Hex package)"]}
      refute_received {:mix_shell, :info, ["* ex_doc (Hex package)"]}
      assert_received {:mix_shell, :info, ["* ex_doc" <> _]}

      assert Mix.Dep.Lock.read == %{postgrex: {:hex, :postgrex, "0.2.1"}}
    end
  after
    purge [OverrideWithPath.NoConflict.Mixfile, ExDoc.Fixture.Mixfile,
           Postgrex.NoConflict.Mixfile]
  end

  test "optional dependency" do
    Mix.Project.push Optional

    in_tmp fn ->
      Hex.State.put(:home, System.cwd!)

      Mix.Task.run "deps.get"

      assert_received {:mix_shell, :info, ["* Getting only_doc (Hex package)"]}
      refute_received {:mix_shell, :info, ["* Getting ex_doc (Hex package)"]}

      Mix.Task.run "deps"

      assert_received {:mix_shell, :info, ["* only_doc (Hex package)"]}
      refute_received {:mix_shell, :info, ["* ex_doc (Hex package)"]}
    end
  after
    purge [ Only_doc.NoConflict.Mixfile, Ex_doc.NoConflict.Mixfile ]
  end

  test "with optional dependency" do
    Mix.Project.push WithOptional

    in_tmp fn ->
      Hex.State.put(:home, System.cwd!)

      Mix.Task.run "deps.get"

      assert_received {:mix_shell, :info, ["* Getting only_doc (Hex package)"]}
      assert_received {:mix_shell, :info, ["* Getting ex_doc (Hex package)"]}

      Mix.Task.run "deps"

      assert_received {:mix_shell, :info, ["* only_doc (Hex package)"]}
      assert_received {:mix_shell, :info, ["* ex_doc (Hex package)"]}
      assert_received {:mix_shell, :info, ["  locked at 0.0.1 (ex_doc)"]}
    end
  after
    purge [ Only_doc.NoConflict.Mixfile, Ex_doc.NoConflict.Mixfile ]
  end

  test "with package name" do
    Mix.Project.push WithPackageName

    in_tmp fn ->
      Hex.State.put(:home, System.cwd!)

      Mix.Task.run "deps.get"

      assert_received {:mix_shell, :info, ["* Getting app_name (Hex package)"]}

      Mix.Task.run "deps"

      assert_received {:mix_shell, :info, ["* app_name (Hex package)"]}
      assert_received {:mix_shell, :info, ["  locked at 0.1.0 (package_name)"]}
    end
  after
    purge [ Package_name.NoConflict.Mixfile ]
  end

  test "with depend name" do
    Mix.Project.push WithDependName

    in_tmp fn ->
      Hex.State.put(:home, System.cwd!)

      Mix.Task.run "deps.get"

      assert_received {:mix_shell, :info, ["* Getting depend_name (Hex package)"]}
      assert_received {:mix_shell, :info, ["* Getting app_name (Hex package)"]}

      Mix.Task.run "deps"

      assert_received {:mix_shell, :info, ["* depend_name (Hex package)"]}
      assert_received {:mix_shell, :info, ["  locked at 0.2.0 (depend_name)"]}
      assert_received {:mix_shell, :info, ["* app_name (Hex package)"]}
      assert_received {:mix_shell, :info, ["  locked at 0.1.0 (package_name)"]}
    end
  after
    purge [ Depend_name.NoConflict.Mixfile, Package_name.NoConflict.Mixfile ]
  end
end
