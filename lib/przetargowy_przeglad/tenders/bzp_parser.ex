defmodule PrzetargowyPrzeglad.Tenders.BzpParser do
  @moduledoc """
  Parses BZP (Biuletyn Zamówień Publicznych) tender HTML announcements
  and extracts structured data.

  Requires `floki` in mix.exs:
      {:floki, "~> 0.36"}
  """

  @type criterion :: %{
          name: String.t(),
          weight: integer(),
          kind: String.t() | nil
        }

  @type parsed_tender :: %{
          wadium: String.t() | nil,
          wadium_amount: Decimal.t() | nil,
          kryteria: [criterion()],
          okres_realizacji: %{from: Date.t() | nil, to: Date.t() | nil, raw: String.t()},
          opis_przedmiotu: String.t() | nil,
          warunki_udzialu: String.t() | nil,
          cpv_main: String.t() | nil,
          cpv_additional: [String.t()],
          nazwa_zamowienia: String.t() | nil,
          zamawiajacy: %{
            nazwa: String.t() | nil,
            miejscowosc: String.t() | nil,
            wojewodztwo: String.t() | nil,
            kod_pocztowy: String.t() | nil,
            ulica: String.t() | nil,
            email: String.t() | nil,
            www: String.t() | nil,
            regon: String.t() | nil
          },
          termin_skladania_ofert: String.t() | nil,
          numer_ogloszenia: String.t() | nil,
          data_ogloszenia: String.t() | nil,
          numer_referencyjny: String.t() | nil,
          oferty_czesciowe: boolean() | nil,
          zabezpieczenie: boolean() | nil,
          evaluation_criteria: String.t() | nil
        }

  @doc """
  Parses raw BZP HTML and returns a structured map.

  ## Example

      {:ok, parsed} = BzpParser.parse(html_string)
      parsed.wadium_amount
      #=> #Decimal<4000.00>
      parsed.kryteria
      #=> [%{name: "Cena", weight: 60, kind: nil}, ...]
  """
  @spec parse(String.t()) :: {:ok, parsed_tender()} | {:error, term()}
  def parse(html) when is_binary(html) do
    case Floki.parse_document(html) do
      {:ok, document} ->
        {:ok, extract_all(document)}

      {:error, reason} ->
        {:error, {:parse_error, reason}}
    end
  end

  def parse!(html) do
    case parse(html) do
      {:ok, result} -> result
      {:error, reason} -> raise "BZP parse error: #{inspect(reason)}"
    end
  end

  # ---------------------------------------------------------------------------
  # Main extraction
  # ---------------------------------------------------------------------------

  defp extract_all(doc) do
    %{
      wadium: extract_wadium_text(doc),
      wadium_amount: extract_wadium_amount(doc),
      kryteria: extract_kryteria(doc),
      okres_realizacji: extract_okres_realizacji(doc),
      opis_przedmiotu: extract_by_section(doc, "4.2.2."),
      warunki_udzialu: extract_warunki_udzialu(doc),
      cpv_main: extract_cpv_main(doc),
      cpv_additional: extract_cpv_additional(doc),
      nazwa_zamowienia: extract_by_section(doc, "2.3."),
      zamawiajacy: extract_zamawiajacy(doc),
      termin_skladania_ofert: extract_span_value(doc, "8.1."),
      numer_ogloszenia: extract_span_value(doc, "2.5."),
      data_ogloszenia: extract_span_value(doc, "2.7."),
      numer_referencyjny: extract_span_value(doc, "4.1.2."),
      oferty_czesciowe: extract_boolean(doc, "4.1.8."),
      zabezpieczenie: extract_boolean(doc, "6.5."),
      evaluation_criteria: extract_evaluation_criteria(doc)
    }
  end

  # ---------------------------------------------------------------------------
  # Wadium
  # ---------------------------------------------------------------------------

  defp extract_wadium_text(doc) do
    doc
    |> find_section_content("6.4.1)")
    |> clean_text()
    |> case do
      "" -> nil
      text -> text
    end
  end

  defp extract_wadium_amount(doc) do
    case extract_wadium_text(doc) do
      nil ->
        nil

      text ->
        # Match Polish number formats: "4 000,00" or "4000,00" or "4000.00"
        case Regex.run(~r/(\d[\d\s]*[\d])[,.](\d{2})\s*zł/, text) do
          [_, integer_part, decimal_part] ->
            integer_part
            |> String.replace(~r/\s/, "")
            |> Kernel.<>("." <> decimal_part)
            |> Decimal.new()

          nil ->
            # Try simpler pattern: just digits before "zł"
            case Regex.run(~r/([\d\s]+)\s*zł/, text) do
              [_, amount] ->
                amount |> String.replace(~r/\s/, "") |> Decimal.new()

              nil ->
                nil
            end
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Kryteria oceny ofert
  # ---------------------------------------------------------------------------

  defp extract_kryteria(doc) do
    # Find all h3 elements, then walk through them looking for criterion patterns
    all_h3s = Floki.find(doc, "h3")

    all_h3s
    |> Enum.with_index()
    |> Enum.reduce({[], nil}, fn {h3, idx}, {criteria, current_kind} ->
      text = h3 |> Floki.text() |> clean_text()

      cond do
        # "4.3.4.) Rodzaj kryterium:" — sets the kind for the next criterion
        String.contains?(text, "4.3.4.)") ->
          kind =
            text
            |> String.split("4.3.4.)")
            |> List.last()
            |> String.replace(~r/^[^:]*:\s*/, "")
            |> clean_text()

          # Kind text might also be in the next sibling text node
          kind =
            if kind == "" do
              get_following_text(all_h3s, idx)
            else
              kind
            end

          {criteria, kind}

        # "4.3.5.) Nazwa kryterium:" — extract name
        String.contains?(text, "4.3.5.)") ->
          name = extract_after_colon(text)

          criterion = %{
            name: name,
            weight: nil,
            kind: current_kind
          }

          {criteria ++ [criterion], current_kind}

        # "4.3.6.) Waga:" — extract weight and attach to last criterion
        String.contains?(text, "4.3.6.)") ->
          weight =
            text
            |> extract_after_colon()
            |> parse_integer()

          criteria =
            case List.pop_at(criteria, -1) do
              {nil, _} ->
                criteria

              {last, rest} ->
                rest ++ [%{last | weight: weight}]
            end

          # Reset kind after full criterion is parsed
          {criteria, nil}

        true ->
          {criteria, current_kind}
      end
    end)
    |> elem(0)
  end

  # ---------------------------------------------------------------------------
  # Okres realizacji
  # ---------------------------------------------------------------------------

  defp extract_okres_realizacji(doc) do
    raw = extract_span_value(doc, "4.2.10.") || ""

    {from_date, to_date} =
      case Regex.run(~r/(\d{4}-\d{2}-\d{2}).*?(\d{4}-\d{2}-\d{2})/, raw) do
        [_, from_str, to_str] ->
          {parse_date(from_str), parse_date(to_str)}

        nil ->
          # Try "X miesięcy/dni" pattern
          {nil, nil}
      end

    %{from: from_date, to: to_date, raw: clean_text(raw)}
  end

  # ---------------------------------------------------------------------------
  # Warunki udziału
  # ---------------------------------------------------------------------------

  defp extract_warunki_udzialu(doc) do
    doc
    |> find_section_content("5.4.)")
    |> clean_text()
    |> case do
      "" -> nil
      text -> text
    end
  end

  # ---------------------------------------------------------------------------
  # Evaluation criteria
  # Extracts evaluation criteria from different sections based on notice type:
  # - CompetitionNotice: Section 3.7 "Informacja o obiektywnych wymaganiach"
  # - AgreementIntentionNotice: Section 4.2 "Uzasadnienie faktyczne i prawne"
  # ---------------------------------------------------------------------------

  defp extract_evaluation_criteria(doc) do
    # Try CompetitionNotice section first (3.7 - objective requirements)
    # Only match if it's "Informacja o obiektywnych wymaganiach"
    case extract_section_with_header_match(doc, "3.7.)", "obiektywnych wymaganiach") do
      text when is_binary(text) and text != "" ->
        text

      _ ->
        # Try AgreementIntentionNotice section (4.2 - legal justification)
        # Only match if it's "Uzasadnienie faktyczne i prawne"
        case extract_section_with_header_match(doc, "4.2.)", "Uzasadnienie faktyczne") do
          text when is_binary(text) and text != "" ->
            text

          _ ->
            nil
        end
    end
  end

  # Extracts text content after a section header that matches both prefix and keyword
  defp extract_section_with_header_match(doc, section_prefix, header_keyword) do
    main_elements = Floki.find(doc, "main")

    main =
      case main_elements do
        [] -> doc
        [m | _] -> m
      end

    children = get_children(main)
    extract_text_after_section_with_match(children, section_prefix, header_keyword)
  end

  # Get children from a Floki element, handling different structures
  defp get_children({_tag, _attrs, children}), do: children
  defp get_children([{_tag, _attrs, children} | _]), do: children
  defp get_children(_), do: []

  # Walk through children looking for the section with matching header, then collect text until next heading
  defp extract_text_after_section_with_match(children, section_prefix, header_keyword) do
    children
    |> Enum.reduce({:searching, []}, fn child, {state, acc} ->
      case state do
        :searching ->
          # Check if this is an h3 with our section prefix AND contains the keyword
          if is_h3_with_prefix_and_keyword?(child, section_prefix, header_keyword) do
            {:collecting, []}
          else
            {:searching, []}
          end

        :collecting ->
          cond do
            is_heading?(child) ->
              {:done, acc}

            true ->
              text = extract_node_text(child) |> String.trim()

              if text != "" do
                {:collecting, acc ++ [text]}
              else
                {:collecting, acc}
              end
          end

        :done ->
          {:done, acc}
      end
    end)
    |> case do
      {:collecting, parts} -> parts |> Enum.join(" ") |> clean_text()
      {:done, parts} -> parts |> Enum.join(" ") |> clean_text()
      _ -> nil
    end
  end

  defp is_h3_with_prefix_and_keyword?({tag, _attrs, _children} = el, prefix, keyword)
       when tag in ["h3", "H3"] do
    text = Floki.text(el)
    String.contains?(text, prefix) and String.contains?(text, keyword)
  end

  defp is_h3_with_prefix_and_keyword?(_, _, _), do: false

  defp is_heading?({tag, _attrs, _children}) when tag in ["h2", "h3", "H2", "H3"], do: true
  defp is_heading?(_), do: false

  # Extract text from a node (handles both text nodes and elements)
  defp extract_node_text(text) when is_binary(text), do: text

  defp extract_node_text({:comment, _}), do: ""

  defp extract_node_text({_tag, _attrs, _children} = el) do
    Floki.text(el)
  end

  defp extract_node_text(_), do: ""

  # ---------------------------------------------------------------------------
  # CPV codes
  # ---------------------------------------------------------------------------

  defp extract_cpv_main(doc) do
    extract_span_value(doc, "4.2.6.")
  end

  defp extract_cpv_additional(doc) do
    # Find the h3 with "4.2.7.)" then collect all following <p> siblings
    all_h3s = Floki.find(doc, "h3")

    case Enum.find_index(all_h3s, fn h3 ->
           h3 |> Floki.text() |> String.contains?("4.2.7.)")
         end) do
      nil ->
        []

      _idx ->
        # The additional CPV codes are in <p> tags after the 4.2.7 heading
        doc
        |> Floki.find("h3, p")
        |> collect_p_after_section("4.2.7.)")
    end
  end

  # ---------------------------------------------------------------------------
  # Zamawiający (contracting authority)
  # ---------------------------------------------------------------------------

  defp extract_zamawiajacy(doc) do
    %{
      nazwa: extract_span_value(doc, "1.2."),
      miejscowosc: extract_span_value(doc, "1.5.2."),
      wojewodztwo: extract_span_value(doc, "1.5.4."),
      kod_pocztowy: extract_span_value(doc, "1.5.3."),
      ulica: extract_span_value(doc, "1.5.1."),
      email: extract_span_value(doc, "1.5.9."),
      www: extract_span_value(doc, "1.5.10."),
      regon:
        doc
        |> extract_span_value("1.4)")
        |> then(fn
          nil -> nil
          text -> String.replace(text, ~r/^REGON\s*/, "")
        end)
    }
  end

  # ---------------------------------------------------------------------------
  # Generic section helpers
  # ---------------------------------------------------------------------------

  @doc false
  defp extract_span_value(doc, section_num) do
    doc
    |> Floki.find("h3")
    |> Enum.find(fn h3 ->
      h3 |> Floki.text() |> String.contains?(section_num)
    end)
    |> case do
      nil ->
        nil

      h3 ->
        # First try to get the value from a <span class="normal"> child
        case Floki.find(h3, "span.normal") do
          [] ->
            # Fall back to text after colon
            h3 |> Floki.text() |> extract_after_colon()

          spans ->
            spans |> Enum.map_join(" ", &Floki.text/1) |> clean_text()
        end
    end
  end

  defp extract_by_section(doc, section_num) do
    # For sections where content is in a <p> tag following the <h3>
    elements = Floki.find(doc, "h3, p")

    elements
    |> Enum.with_index()
    |> Enum.find(fn {el, _idx} ->
      tag_name(el) == "h3" and el |> Floki.text() |> String.contains?(section_num)
    end)
    |> case do
      nil ->
        nil

      {_h3, idx} ->
        # Get the next <p> sibling
        elements
        |> Enum.drop(idx + 1)
        |> Enum.find(fn el -> tag_name(el) == "p" end)
        |> case do
          nil -> nil
          p -> p |> Floki.text() |> clean_text()
        end
    end
  end

  defp extract_boolean(doc, section_num) do
    case extract_span_value(doc, section_num) do
      nil -> nil
      text -> not String.contains?(String.downcase(text), "nie")
    end
  end

  # Finds content after a section heading — handles both inline text and
  # following sibling text nodes / <br>-separated content
  defp find_section_content(doc, section_prefix) do
    # Strategy: find in the raw Floki tree by walking nodes
    all_elements = Floki.find(doc, "h3")

    target_idx =
      Enum.find_index(all_elements, fn h3 ->
        h3 |> Floki.text() |> String.contains?(section_prefix)
      end)

    case target_idx do
      nil ->
        ""

      idx ->
        # Get text content between this h3 and the next h3/h2
        h3 = Enum.at(all_elements, idx)

        # For sections like 5.4 and 6.4.1, content follows the heading
        # as mixed text/br nodes before the next heading
        # We use a broader approach: find all text in the parent between markers
        parent_text = get_text_after_heading(doc, section_prefix)
        parent_text || Floki.text(h3)
    end
  end

  defp get_text_after_heading(doc, section_prefix) do
    # Find all h2, h3, p, and text nodes in document order
    # Collect text from after our target heading until the next h2 or h3
    all = Floki.find(doc, "h2, h3, p, br")

    all
    |> Enum.reduce({:searching, []}, fn el, {state, acc} ->
      tag = tag_name(el)
      text = el |> Floki.text() |> String.trim()

      case state do
        :searching ->
          if tag == "h3" and String.contains?(text, section_prefix) do
            {:collecting, []}
          else
            {:searching, []}
          end

        :collecting ->
          if tag in ["h2", "h3"] do
            {:done, acc}
          else
            {:collecting, acc ++ [text]}
          end

        :done ->
          {:done, acc}
      end
    end)
    |> case do
      {:collecting, parts} -> parts |> Enum.join(" ") |> clean_text()
      {:done, parts} -> parts |> Enum.join(" ") |> clean_text()
      _ -> nil
    end
  end

  defp collect_p_after_section(elements, section_prefix) do
    elements
    |> Enum.reduce({:searching, []}, fn el, {state, acc} ->
      tag = tag_name(el)
      text = el |> Floki.text() |> clean_text()

      case state do
        :searching ->
          if tag == "h3" and String.contains?(text, section_prefix) do
            {:collecting, []}
          else
            {:searching, []}
          end

        :collecting ->
          if tag == "p" and text != "" do
            {:collecting, acc ++ [text]}
          else
            if tag == "h3", do: {:done, acc}, else: {:collecting, acc}
          end

        :done ->
          {:done, acc}
      end
    end)
    |> case do
      {_, items} -> items
    end
  end

  # ---------------------------------------------------------------------------
  # Text utilities
  # ---------------------------------------------------------------------------

  defp clean_text(nil), do: ""

  defp clean_text(text) do
    text
    |> String.replace(~r/[\n\r\t]+/, " ")
    |> String.replace(~r/\s{2,}/, " ")
    |> String.replace(~r/\x{00a0}/u, " ")
    |> String.trim()
  end

  defp extract_after_colon(text) do
    case String.split(text, ":", parts: 2) do
      [_, value] -> clean_text(value)
      _ -> clean_text(text)
    end
  end

  defp parse_integer(str) do
    case Integer.parse(String.trim(str)) do
      {num, _} -> num
      :error -> nil
    end
  end

  defp parse_date(str) do
    case Date.from_iso8601(str) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp tag_name({tag, _attrs, _children}) when is_binary(tag), do: tag
  defp tag_name(_), do: nil

  defp get_following_text(all_h3s, current_idx) do
    # Look at text nodes between this h3 and the next one
    # This is a simplified approach — in practice the kind text
    # is often a bare text node after the h3 in the DOM
    case Enum.at(all_h3s, current_idx + 1) do
      nil -> nil
      _next -> ""
    end
  end
end
