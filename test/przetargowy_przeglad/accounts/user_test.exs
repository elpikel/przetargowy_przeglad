defmodule PrzetargowyPrzeglad.Accounts.UserTest do
  use PrzetargowyPrzeglad.DataCase, async: true

  alias PrzetargowyPrzeglad.Accounts.User

  describe "registration_changeset/2" do
    @valid_attrs %{
      email: "test@example.com",
      password: "password123"
    }

    test "validates required fields" do
      changeset = User.registration_changeset(%User{}, %{})
      refute changeset.valid?
      errors = errors_on(changeset)
      assert "to pole jest wymagane" in errors.email || "can't be blank" in errors.email
      assert "to pole jest wymagane" in errors.password || "can't be blank" in errors.password
    end

    test "validates email format" do
      invalid_emails = ["invalid", "invalid@", "@invalid.com", "invalid@com"]

      for email <- invalid_emails do
        changeset = User.registration_changeset(%User{}, Map.put(@valid_attrs, :email, email))
        assert "nieprawidłowy format adresu e-mail" in errors_on(changeset).email
      end
    end

    test "accepts valid email formats" do
      valid_emails = [
        "test@example.com",
        "user.name@example.co.uk",
        "user+tag@example.com"
      ]

      for email <- valid_emails do
        changeset = User.registration_changeset(%User{}, Map.put(@valid_attrs, :email, email))
        assert changeset.valid?
      end
    end

    test "validates email length" do
      long_email = String.duplicate("a", 150) <> "@example.com"
      changeset = User.registration_changeset(%User{}, Map.put(@valid_attrs, :email, long_email))
      assert "adres e-mail jest za długi" in errors_on(changeset).email
    end

    test "validates password length minimum" do
      changeset = User.registration_changeset(%User{}, Map.put(@valid_attrs, :password, "short"))
      assert "hasło musi mieć co najmniej 8 znaków" in errors_on(changeset).password
    end

    test "validates password length maximum" do
      long_password = String.duplicate("a", 81)
      changeset = User.registration_changeset(%User{}, Map.put(@valid_attrs, :password, long_password))
      assert "hasło jest za długie" in errors_on(changeset).password
    end

    test "hashes password" do
      changeset = User.registration_changeset(%User{}, @valid_attrs)
      assert changeset.valid?
      hashed_password = Ecto.Changeset.get_change(changeset, :password)
      assert hashed_password != "password123"
      assert String.starts_with?(hashed_password, "$2b$")
    end

    test "generates verification token" do
      changeset = User.registration_changeset(%User{}, @valid_attrs)
      assert changeset.valid?
      token = Ecto.Changeset.get_change(changeset, :email_verification_token)
      assert token
      assert is_binary(token)
      assert String.length(token) > 30
    end

    test "sets email_verified to false" do
      changeset = User.registration_changeset(%User{}, @valid_attrs)
      # Check if it's set as a change or use get_field which includes defaults
      email_verified =
        Ecto.Changeset.get_change(changeset, :email_verified) || Ecto.Changeset.get_field(changeset, :email_verified)

      assert email_verified == false
    end

    test "sets email_verification_sent_at" do
      changeset = User.registration_changeset(%User{}, @valid_attrs)
      sent_at = Ecto.Changeset.get_change(changeset, :email_verification_sent_at)
      assert %DateTime{} = sent_at
    end

    test "validates subscription plan" do
      invalid_changeset = User.registration_changeset(%User{}, Map.put(@valid_attrs, :subscription_plan, "invalid"))
      refute invalid_changeset.valid?

      free_changeset = User.registration_changeset(%User{}, Map.put(@valid_attrs, :subscription_plan, "free"))
      assert free_changeset.valid?

      paid_changeset = User.registration_changeset(%User{}, Map.put(@valid_attrs, :subscription_plan, "paid"))
      assert paid_changeset.valid?
    end
  end

  describe "changeset/2" do
    test "updates email and subscription_plan" do
      user = %User{email: "old@example.com", subscription_plan: "free"}
      changeset = User.changeset(user, %{email: "new@example.com", subscription_plan: "paid"})

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :email) == "new@example.com"
      assert Ecto.Changeset.get_change(changeset, :subscription_plan) == "paid"
    end

    test "does not allow password update" do
      user = %User{email: "test@example.com"}
      changeset = User.changeset(user, %{password: "newpassword"})

      # Password field should not be in changes
      refute Ecto.Changeset.get_change(changeset, :password)
    end
  end

  describe "verify_email_changeset/1" do
    test "sets email_verified to true and clears token" do
      user = %User{
        email: "test@example.com",
        email_verified: false,
        email_verification_token: "some-token"
      }

      changeset = User.verify_email_changeset(user)
      assert Ecto.Changeset.get_change(changeset, :email_verified) == true
      assert Ecto.Changeset.get_change(changeset, :email_verification_token) == nil
    end
  end

  describe "verify_password/2" do
    test "returns true for correct password" do
      password = "password123"
      hashed = Bcrypt.hash_pwd_salt(password)

      assert User.verify_password(password, hashed) == true
    end

    test "returns false for incorrect password" do
      password = "password123"
      hashed = Bcrypt.hash_pwd_salt(password)

      assert User.verify_password("wrongpassword", hashed) == false
    end
  end
end
