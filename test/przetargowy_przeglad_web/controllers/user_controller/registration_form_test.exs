defmodule PrzetargowyPrzegladWeb.UserController.RegistrationFormTest do
  use PrzetargowyPrzeglad.DataCase, async: true

  alias PrzetargowyPrzegladWeb.UserController.RegistrationForm

  describe "changeset/2" do
    @valid_attrs %{
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123",
      tender_category: "Dostawy",
      region: "mazowieckie",
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
      assert "to pole jest wymagane" in errors.tender_category || "can't be blank" in errors.tender_category
      assert "to pole jest wymagane" in errors.region || "can't be blank" in errors.region
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

    test "validates tender_category is from valid list" do
      valid_categories = ["Dostawy", "Usługi", "Roboty budowlane"]

      for category <- valid_categories do
        changeset = RegistrationForm.changeset(%RegistrationForm{}, Map.put(@valid_attrs, :tender_category, category))
        assert changeset.valid?
      end

      invalid_changeset =
        RegistrationForm.changeset(%RegistrationForm{}, Map.put(@valid_attrs, :tender_category, "invalid"))

      assert "nieprawidłowy rodzaj zamówienia" in errors_on(invalid_changeset).tender_category
    end

    test "validates region is from valid list" do
      valid_regions =
        ~w(dolnoslaskie kujawsko-pomorskie lubelskie lubuskie lodzkie malopolskie mazowieckie opolskie podkarpackie podlaskie pomorskie slaskie swietokrzyskie warminsko-mazurskie wielkopolskie zachodniopomorskie)

      for region <- valid_regions do
        changeset = RegistrationForm.changeset(%RegistrationForm{}, Map.put(@valid_attrs, :region, region))
        assert changeset.valid?
      end

      invalid_changeset = RegistrationForm.changeset(%RegistrationForm{}, Map.put(@valid_attrs, :region, "invalid"))
      assert "nieprawidłowy region" in errors_on(invalid_changeset).region
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
      assert Ecto.Changeset.get_field(changeset, :tender_category) == "Dostawy"
      assert Ecto.Changeset.get_field(changeset, :region) == "mazowieckie"
      assert Ecto.Changeset.get_field(changeset, :terms) == true
    end

    test "keyword field is optional" do
      # Valid without keyword
      changeset_without = RegistrationForm.changeset(%RegistrationForm{}, @valid_attrs)
      assert changeset_without.valid?
      assert Ecto.Changeset.get_field(changeset_without, :keyword) == nil

      # Valid with keyword
      attrs_with_keyword = Map.put(@valid_attrs, :keyword, "oprogramowanie")
      changeset_with = RegistrationForm.changeset(%RegistrationForm{}, attrs_with_keyword)
      assert changeset_with.valid?
      assert Ecto.Changeset.get_field(changeset_with, :keyword) == "oprogramowanie"
    end

    test "accepts various keyword values" do
      keywords = ["meble", "remont", "oprogramowanie", "usługi IT", ""]

      for keyword <- keywords do
        attrs = Map.put(@valid_attrs, :keyword, keyword)
        changeset = RegistrationForm.changeset(%RegistrationForm{}, attrs)
        assert changeset.valid?
      end
    end
  end
end
