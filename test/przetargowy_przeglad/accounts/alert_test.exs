defmodule PrzetargowyPrzeglad.Accounts.AlertTest do
  use PrzetargowyPrzeglad.DataCase, async: true

  alias PrzetargowyPrzeglad.Accounts.Alert
  alias PrzetargowyPrzeglad.Accounts.User
  alias PrzetargowyPrzeglad.Repo

  describe "simple_alert_changeset/2" do
    setup do
      user =
        Repo.insert!(%User{
          email: "test@example.com",
          password: "hashed_password",
          email_verified: false
        })

      %{user: user}
    end

    test "creates alert with simple rules", %{user: user} do
      attrs = %{
        user_id: user.id,
        region: "mazowieckie",
        industry: "it"
      }

      changeset = Alert.simple_alert_changeset(%Alert{}, attrs)
      assert changeset.valid?

      rules = Ecto.Changeset.get_change(changeset, :rules)
      assert rules.region == "mazowieckie"
      assert rules.industry == "it"
    end

    test "requires user_id", %{user: _user} do
      attrs = %{
        region: "mazowieckie",
        industry: "it"
      }

      changeset = Alert.simple_alert_changeset(%Alert{}, attrs)
      refute changeset.valid?
      errors = errors_on(changeset)
      assert "to pole jest wymagane" in errors.user_id || "can't be blank" in errors.user_id
    end

    test "requires region", %{user: user} do
      attrs = %{
        user_id: user.id,
        industry: "it"
      }

      changeset = Alert.simple_alert_changeset(%Alert{}, attrs)
      refute changeset.valid?
      assert "region jest wymagany" in errors_on(changeset).rules
    end

    test "requires industry", %{user: user} do
      attrs = %{
        user_id: user.id,
        region: "mazowieckie"
      }

      changeset = Alert.simple_alert_changeset(%Alert{}, attrs)
      refute changeset.valid?
      assert "industry jest wymagany" in errors_on(changeset).rules
    end
  end

  describe "changeset/2" do
    setup do
      user =
        Repo.insert!(%User{
          email: "test@example.com",
          password: "hashed_password",
          email_verified: false
        })

      %{user: user}
    end

    test "creates alert with simple rules format", %{user: user} do
      attrs = %{
        user_id: user.id,
        rules: %{region: "mazowieckie", industry: "it"}
      }

      changeset = Alert.changeset(%Alert{}, attrs)
      assert changeset.valid?
    end

    test "creates alert with advanced rules format", %{user: user} do
      attrs = %{
        user_id: user.id,
        rules: %{
          regions: ["mazowieckie", "malopolskie"],
          industries: ["it", "budownictwo"],
          keywords: ["software"]
        }
      }

      changeset = Alert.changeset(%Alert{}, attrs)
      assert changeset.valid?
    end

    test "requires user_id", %{user: _user} do
      attrs = %{
        rules: %{region: "mazowieckie", industry: "it"}
      }

      changeset = Alert.changeset(%Alert{}, attrs)
      refute changeset.valid?
      errors = errors_on(changeset)
      assert "to pole jest wymagane" in errors.user_id || "can't be blank" in errors.user_id
    end

    test "requires rules", %{user: user} do
      attrs = %{user_id: user.id}

      changeset = Alert.changeset(%Alert{}, attrs)
      refute changeset.valid?
      errors = errors_on(changeset)
      assert "to pole jest wymagane" in errors.rules || "can't be blank" in errors.rules
    end

    test "validates rules format - rejects invalid structure", %{user: user} do
      attrs = %{
        user_id: user.id,
        rules: %{invalid: "structure"}
      }

      changeset = Alert.changeset(%Alert{}, attrs)
      refute changeset.valid?
      assert "nieprawidłowy format reguł" in errors_on(changeset).rules
    end

    test "validates advanced rules - regions must be list", %{user: user} do
      attrs = %{
        user_id: user.id,
        rules: %{
          regions: "not-a-list",
          industries: ["it"]
        }
      }

      changeset = Alert.changeset(%Alert{}, attrs)
      refute changeset.valid?
      assert "regions musi być listą" in errors_on(changeset).rules
    end

    test "validates advanced rules - industries must be list", %{user: user} do
      attrs = %{
        user_id: user.id,
        rules: %{
          regions: ["mazowieckie"],
          industries: "not-a-list"
        }
      }

      changeset = Alert.changeset(%Alert{}, attrs)
      refute changeset.valid?
      assert "industries musi być listą" in errors_on(changeset).rules
    end
  end
end
