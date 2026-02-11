defmodule PrzetargowyPrzegladWeb.UserController.RegistrationFormTest do
  use PrzetargowyPrzeglad.DataCase, async: true

  alias PrzetargowyPrzegladWeb.UserController.RegistrationForm

  describe "changeset/2" do
    @valid_attrs %{
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123",
      terms: true
    }

    test "changeset with valid attributes" do
      changeset = RegistrationForm.changeset(%RegistrationForm{}, @valid_attrs)
      assert changeset.valid?
    end

    test "requires all fields" do
      changeset = RegistrationForm.changeset(%RegistrationForm{}, %{})
      refute changeset.valid?

      errors = errors_on(changeset)
      assert "to pole jest wymagane" in errors.email || "can't be blank" in errors.email
      assert "to pole jest wymagane" in errors.password || "can't be blank" in errors.password
      assert "to pole jest wymagane" in errors.password_confirmation || "can't be blank" in errors.password_confirmation
      # Terms has a custom error message
      assert "musisz zaakceptować regulamin" in errors.terms || "to pole jest wymagane" in errors.terms
    end

    test "validates email format" do
      invalid_emails = ["invalid", "invalid@", "@invalid.com", "invalid@com"]

      for email <- invalid_emails do
        changeset = RegistrationForm.changeset(%RegistrationForm{}, Map.put(@valid_attrs, :email, email))
        assert "nieprawidłowy format adresu e-mail" in errors_on(changeset).email
      end
    end

    test "validates email length" do
      long_email = String.duplicate("a", 150) <> "@example.com"
      changeset = RegistrationForm.changeset(%RegistrationForm{}, Map.put(@valid_attrs, :email, long_email))
      assert "adres e-mail jest za długi" in errors_on(changeset).email
    end

    test "validates password length minimum" do
      changeset = RegistrationForm.changeset(%RegistrationForm{}, Map.put(@valid_attrs, :password, "short"))
      assert "hasło musi mieć co najmniej 8 znaków" in errors_on(changeset).password
    end

    test "validates password length maximum" do
      long_password = String.duplicate("a", 81)
      changeset = RegistrationForm.changeset(%RegistrationForm{}, Map.put(@valid_attrs, :password, long_password))
      assert "hasło jest za długie" in errors_on(changeset).password
    end

    test "validates password confirmation matches" do
      attrs = Map.put(@valid_attrs, :password_confirmation, "different")
      changeset = RegistrationForm.changeset(%RegistrationForm{}, attrs)
      assert "hasła nie są identyczne" in errors_on(changeset).password_confirmation
    end

    test "validates terms acceptance" do
      attrs_false = Map.put(@valid_attrs, :terms, false)
      changeset_false = RegistrationForm.changeset(%RegistrationForm{}, attrs_false)
      assert "musisz zaakceptować regulamin" in errors_on(changeset_false).terms

      attrs_nil = Map.put(@valid_attrs, :terms, nil)
      changeset_nil = RegistrationForm.changeset(%RegistrationForm{}, attrs_nil)
      assert "musisz zaakceptować regulamin" in errors_on(changeset_nil).terms

      attrs_true = Map.put(@valid_attrs, :terms, true)
      changeset_true = RegistrationForm.changeset(%RegistrationForm{}, attrs_true)
      assert changeset_true.valid?
    end

    test "accepts valid registration data" do
      changeset = RegistrationForm.changeset(%RegistrationForm{}, @valid_attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :email) == "test@example.com"
      assert Ecto.Changeset.get_field(changeset, :password) == "password123"
      assert Ecto.Changeset.get_field(changeset, :terms) == true
    end
  end
end
