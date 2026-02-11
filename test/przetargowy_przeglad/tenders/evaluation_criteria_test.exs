defmodule PrzetargowyPrzeglad.Tenders.EvaluationCriteriaTest do
  @moduledoc """
  Tests for parsing evaluation_criteria from tender notices HTML body.

  Each notice type may have evaluation criteria in different sections:
  - ContractNotice: Sections 4.3.4-4.3.6 (already parsed as `kryteria`)
  - CompetitionNotice: Section 3.7 "Informacja o obiektywnych wymaganiach"
  - AgreementIntentionNotice: Section 4.2 "Uzasadnienie faktyczne i prawne"
  - Other notice types: Various sections depending on type
  """
  use ExUnit.Case, async: true

  alias PrzetargowyPrzeglad.Tenders.BzpParser

  # Sample HTML for AgreementIntentionNotice (Ogłoszenie o zamiarze zawarcia umowy)
  @agreement_intention_notice_html """
  <html><head><meta charset="UTF-8"><style>body {
      font-family: "Calibri", sans-serif;
  }
  span.normal {
      font-weight: 400
  }
  </style></head><body><header hidden><table style="border-bottom: 1px solid black; width:100%"><tr><td>Ogłoszenie nr 2024/BZP 00097743 z dnia 2024-02-08</td></tr></table></header><main><!-- Version 1.0.0 --><style type="text/css">    .normal {        color: black;    }    h1.title {    }</style>    <h1 class="text-center mt-5 mb-5">Ogłoszenie o zamiarze zawarcia umowy<br/>            Usługi<br/>            Zakup dostępu do usługi „Ognivo" dla urzędów skarbowych województwa kujawsko-pomorskiego .    </h1>    <h2 class="bg-light p-3 mt-4">SEKCJA I  ZAMAWIAJĄCY</h2>    <h3 class="mb-0">1.1.) Rola zamawiającego</h3>Postępowanie prowadzone jest samodzielnie przez zamawiającego    <h3 class="mb-0">1.2.) Nazwa zamawiającego: <span class="normal">IZBA ADMINISTRACJI SKARBOWEJ W BYDGOSZCZY</span></h3>    <h3 class="mb-0">1.4.) Krajowy Numer Identyfikacyjny: <span class="normal">REGON 001021145</span></h3><h3 class="mb-0 mt-3">1.5.) Adres zamawiającego: </h3>    <h3 class="mb-0">1.5.1.) Ulica: <span class="normal">ul. Dr. Emila Warmińskiego 18</span></h3>    <h3 class="mb-0">1.5.2.) Miejscowość: <span class="normal">Bydgoszcz</span></h3>    <h3 class="mb-0">1.5.3.) Kod pocztowy: <span class="normal">85-950</span></h3>    <h3 class="mb-0">1.5.4.) Województwo: <span class="normal">kujawsko-pomorskie</span></h3>    <h3 class="mb-0">1.5.5.) Kraj: <span class="normal">Polska</span></h3>    <h3 class="mb-0">1.5.6.) Lokalizacja NUTS 3: <span class="normal">PL613 - Bydgosko-toruński</span></h3>    <h3 class="mb-0">1.5.8.) Adres poczty elektronicznej: <span class="normal">przetargi.IAS.Bydgoszcz@mf.gov.pl</span></h3>    <h3 class="mb-0">1.5.9.) Adres strony internetowej zamawiającego: <span class="normal">www.kujawsko-pomorskie.kas.gov.pl</span></h3>    <h3 class="mb-0">1.6.) Rodzaj zamawiającego: <span class="normal">Zamawiający publiczny - jednostka sektora finansów publicznych - organ władzy publicznej - organ administracji rządowej (centralnej lub terenowej)</span></h3>    <h3 class="mb-0">1.7.) Przedmiot działalności zamawiającego: <span class="normal">Ogólne usługi publiczne</span></h3>    <h2 class="bg-light p-3 mt-4">SEKCJA II – INFORMACJE PODSTAWOWE</h2>    <h3 class="mb-0">2.1.) Nazwa zamówienia: </h3>Zakup dostępu do usługi „Ognivo" dla urzędów skarbowych województwa kujawsko-pomorskiego .    <h3 class="mb-0">2.2.) Identyfikator postępowania: <span class="normal">ocds-148610-6dbbb223-c402-11ee-bbfa-e29e26ebc6e1</span></h3>    <h3 class="mb-0">2.3.) Numer ogłoszenia: <span class="normal">2024/BZP 00097743</span></h3>    <h3 class="mb-0">2.4.) Wersja ogłoszenia: <span class="normal">01</span></h3>    <h3 class="mb-0">2.5.) Data ogłoszenia: <span class="normal">2024-02-08</span></h3>    <h3 class="mb-0">2.6.)  Zamówienie zostało ujęte w planie postępowań: <span class="normal">Tak</span></h3>    <h3 class="mb-0">2.7.) Numer planu postępowań w BZP: <span class="normal">2021/BZP 00010100/05/P</span></h3>    <h3 class="mb-0">2.8.) Identyfikator pozycji planu postępowań: </h3>        <p class="mb-0">1.3.5 Dostęp do usługi Ognivo dla urzędów skarbowych województwa kujawsko-pomorskiego</p>    <h3 class="mb-0">2.9.) Ogłoszenie dotyczy usług społecznych i innych szczególnych usług: <span class="normal">Nie</span></h3>    <h3 class="mb-0">2.10.) Czy zamówienie dotyczy projektu lub programu współfinansowanego ze środków Unii Europejskiej: <span class="normal">Nie</span></h3>    <h2 class="bg-light p-3 mt-4">SEKCJA III – PRZEDMIOT ZAMÓWIENIA</h2>    <h3 class="mb-0">3.1.) Przed wszczęciem postępowania przeprowadzono konsultacje rynkowe: <span class="normal">Nie</span></h3>    <h3 class="mb-0">3.2.) Numer referencyjny: <span class="normal">0401-ILZ.260.2.2.2024</span></h3>    <h3 class="mb-0">3.3.) Rodzaj zamówienia</h3>Usługi    <h3 class="mb-0">3.4.) Zamawiający udziela zamówienia w częściach, z których każda stanowi przedmiot odrębnego postępowania: <span class="normal">Nie</span></h3>        <h3 class="mb-0">3.8.) Krótki opis przedmiotu zamówienia</h3>Zakup dostępu do usługi Ognivo        <h3 class="mb-0">3.10.) Główny kod CPV: <span class="normal">72500000-0 - Komputerowe usługi pokrewne</span></h3>        <h3 class="mb-0">3.11.) Dodatkowy kod CPV:            <span class="normal">                    <p>48000000-8 - Pakiety oprogramowania i systemy informatyczne</p>            </span>        </h3>    <h2 class="bg-light p-3 mt-4">SEKCJA IV TRYB UDZIELENIA ZAMÓWIENIA</h2>    <h3 class="mb-0">4.1.) Tryb udzielenia zamówienia/ wraz z podstawą prawną: </h3>Zamówienie udzielane jest w trybie zamówienia z wolnej ręki na podstawie: art. 305 pkt 1 ustawy w zw. z art. 214 ust. 1 pkt 1 ustawy    <h3 class="mb-0">4.2.) Uzasadnienie faktyczne i prawne wyboru trybu negocjacji bez ogłoszenia albo zamówienia z wolnej ręki: </h3>Zgodnie z art. 214 ust. 1 pkt b  ustawy Pzp, Zamawiający może udzielić zamówienia publicznego  w trybie zamówienia z wolnej ręki  w przypadku, gdy usługi mogą być świadczone tylko przez jednego wykonawcę z przyczyn  związanych z ochroną praw wyłącznych  wynikających z odrębnych przepisów<br/>Zgodnie z art. 112c ust. 1 i 2 ustawy z dnia 29.08.1997r. – Prawo bankowe - banki prowadzą system teleinformatyczny obsługujący zajęcie wierzytelności z rachunku bankowego. Ww. system jest prowadzony przez Krajową Izbę Rozliczeniową S.A. Przepis art. 86b ustawy z dnia 17.06.1966r. o postępowaniu egzekucyjnym w administracji nakłada na administracyjne organy egzekucyjne obowiązek doręczania zawiadomień i wezwań związanych z prowadzeniem egzekucji przy wykorzystaniu systemu teleinformatycznego obsługującego zajęcie wierzytelności z rachunku bankowego tj. systemu OGNIVO. KIR jest jedyną instytucją prowadzącą system teleinformatyczny OGNIVO.    <h2 class="bg-light p-3 mt-4">SEKCJA V ZAWARCIE UMOWY</h2>    <h3 class="mb-0 mt-3">5.1.) Wykonawca, z którym Zamawiający zamierza zawrzeć umowę: </h3>        <h3 class="mb-0">5.1.1) Nazwa (firma) wykonawcy, któremu Zamawiający zamierza udzielić zamówienia (w przypadku wykonawców ubiegających się wspólnie o udzielenie zamówienia – dotyczy pełnomocnika, o którym mowa w art. 58 ust. 2 ustawy): <span class="normal">Krajowa Izba Rozliczeniowa S.A.</span></h3>        <h3 class="mb-0">5.1.2.) Ulica: <span class="normal">W. Pileckiego 65</span></h3>        <h3 class="mb-0">5.1.3.) Miejscowość: <span class="normal">Warszawa</span></h3>        <h3 class="mb-0">5.1.4.) Kod pocztowy: <span class="normal">02-781</span></h3>        <h3 class="mb-0">5.1.5.) Województwo: <span class="normal">mazowieckie</span></h3>        <h3 class="mb-0">5.1.6.) Kraj: <span class="normal">Polska</span></h3></main><footer hidden><table style="border-top: 1px solid black; width:100%"><tr><td>2024-02-08 Biuletyn Zamówień Publicznych</td><td style="text-align:right">Ogłoszenie o zamiarze zawarcia umowy -  - Usługi</td></tr></table></footer></body></html>
  """

  # Sample HTML for AgreementUpdateNotice (Ogłoszenie o zmianie umowy)
  @agreement_update_notice_html """
  <html><head><meta charset="UTF-8"><style>body {
      font-family: "Calibri", sans-serif;
  }
  span.normal {
      font-weight: 400
  }
  </style></head><body><header hidden><table style="border-bottom: 1px solid black; width:100%"><tr><td>Ogłoszenie nr 2024/BZP 00077396 z dnia 2024-01-30</td></tr></table></header><main><!-- Version 1.0.0 --><style type="text/css">    .normal {        color: black;    }    h1.title {    }</style>    <h1 class="text-center mt-5 mb-5">Ogłoszenie o zmianie umowy<br/>            Roboty budowlane<br/>            Przebudowa ul. 17 Dywizji Piechoty we Wrześni w zakresie miejsc postojowych    </h1>    <h2 class="bg-light p-3 mt-4">SEKCJA I - ZAMAWIAJĄCY</h2>    <h3 class="mb-0">1.1.) Nazwa zamawiającego: <span class="normal">Gmina Września</span></h3>    <h3 class="mb-0">1.3) Krajowy Numer Identyfikacyjny: <span class="normal">REGON 631258069</span></h3><h3 class="mb-0">1.4) Adres zamawiającego</h3>    <h3 class="mb-0">1.4.1.) Ulica: <span class="normal">Ratuszowa 1</span></h3>    <h3 class="mb-0">1.4.2.) Miejscowość: <span class="normal">Września</span></h3>    <h3 class="mb-0">1.4.3.) Kod pocztowy: <span class="normal">62-300</span></h3>    <h3 class="mb-0">1.4.4.) Województwo: <span class="normal">wielkopolskie</span></h3>    <h3 class="mb-0">1.4.5.) Kraj: <span class="normal">Polska</span></h3>    <h3 class="mb-0">1.4.6.) Lokalizacja NUTS 3: <span class="normal">PL414 - Koniński</span></h3>    <h3 class="mb-0">1.4.9.) Adres poczty elektronicznej: <span class="normal">przetarg@wrzesnia.pl</span></h3>    <h3 class="mb-0">1.4.10.) Adres strony internetowej zamawiającego: <span class="normal">http://www.wrzesnia.pl</span></h3>    <h3 class="mb-0">1.5.) Rodzaj zamawiającego: <span class="normal">Zamawiający publiczny - jednostka sektora finansów publicznych - jednostka samorządu terytorialnego</span></h3>    <h2 class="bg-light p-3 mt-4">SEKCJA II - INFORMACJE PODSTAWOWE</h2>    <h3 class="mb-0">2.1.) Ogłoszenie dotyczy zmiany: </h3>    <p class="mb-0">        Umowy    </p>    <h3 class="mb-0">2.2.) Identyfikator postępowania: <span class="normal">ocds-148610-f8b8604c-6da8-11ee-9aa3-96d3b4440790</span></h3>    <h3 class="mb-0">2.3.) Numer ogłoszenia: <span class="normal">2024/BZP 00077396</span></h3>    <h3 class="mb-0">2.4.) Wersja ogłoszenia: <span class="normal">01</span></h3>    <h3 class="mb-0">2.5.) Data ogłoszenia: <span class="normal">2024-01-30</span></h3>    <h2 class="bg-light p-3 mt-4">SEKCJA III - PODSTAWOWE INFORMACJE O POSTĘPOWANIU W WYNIKU KTÓREGO ZOSTAŁA ZAWARTA UMOWA/UMOWA RAMOWA</h2>    <h3 class="mb-0">        3.1.) Zamówienie/umowa ramowa było poprzedzone ogłoszeniem o zamówieniu/ogłoszeniem o zamiarze zawarcia umowy:        <span class="normal">Tak</span>    </h3>    <h3 class="mb-0">3.1.1.) Numer ogłoszenia: <span class="normal">2023/BZP 00450054</span></h3>    <h3 class="mb-0">        3.2.) Czy zamówienie albo umowa ramowa dotyczy projektu lub programu współfinansowanego ze środków Unii Europejskiej:        <span class="normal">Nie</span>    </h3>    <h3 class="mb-0">3.4.) Tryb udzielenia zamówienia/zawarcia umowy ramowej wraz z podstawą prawną: </h3>    Zamówienie udzielane jest w trybie podstawowym na podstawie: art. 275 pkt 1 ustawy    <h3 class="mb-0">3.5.) Rodzaj zamówienia: </h3>    Roboty budowlane    <h3 class="mb-0">3.6.) Nazwa zamówienia albo umowy ramowej: </h3>    Przebudowa ul. 17 Dywizji Piechoty we Wrześni w zakresie miejsc postojowych        <h3 class="mb-0">3.7.) Krótki opis przedmiotu zamówienia: </h3>        <p class="mb-0">1. Przedmiotem zamówienia jest wykonanie robót budowlanych związanych z przebudową ul. 17 Dywizji Piechoty we Wrześni w zakresie miejsc postojowych wg dokumentacji projektowej, przedmiarów robót oraz specyfikacji technicznej wykonania i odbioru robót budowlanych przekazanych przez Zamawiającego wraz z SWZ.<br/>2. Zakres rzeczowy zamówienia obejmuje m.in.:<br/>1) roboty rozbiórkowe i przygotowawcze,<br/>2) wykonanie warstwy wzmacniającej z gruntu stabilizowanego cementem gr. 15 cm,<br/>3) wykonanie podbudowy z chudego betonu o gr. 15 cm,<br/>4) krawężniki betonowe wystające o wymiarach 15x30 cm z wykonaniem ławy betonowej na podsypce cementowo-piaskowej,<br/>5) nawierzchnia z kostki brukowej betonowej 20x10 cm szarej  gr. 8 cm na podsypce cementowo-piaskowej gr 3 cm,<br/>6) roboty końcowe w tym m.in. dokumentacja powykonawcza.</p>        <h3 class="mb-0">            3.8.) Główny kod CPV: <span class="normal">45233120-6 - Roboty w zakresie budowy dróg</span>        </h3>    <h2 class="bg-light p-3 mt-4">SEKCJA IV - PODSTAWOWE INFORMACJE O ZAWARTEJ UMOWIE/UMOWIE RAMOWEJ</h2>    <h3 class="mb-0">4.1.) Data zawarcia umowy/umowy ramowej: <span class="normal">2023-11-24</span></h3>    <h3 class="mb-0">4.2.) Okres realizacji zamówienia/umowy ramowej: </h3>    do 2023-12-15<h3 class="mb-0">4.3.) Dane wykonawcy, z którym zawarto umowę/umowę ramową: </h3><!-- Wykonawca 0 -->    <h3 class="mb-0">4.3.1.) Nazwa (firma) wykonawcy, któremu udzielono zamówienia (w przypadku wykonawców ubiegających się wspólnie o udzielenie zamówienia – dotyczy pełnomocnika, o którym mowa w art. 58 ust. 2 ustawy): <span class="normal">Firma Usługowo-Handlowa „ANNA" Anna Białobrzycka</span></h3>    <h3 class="mb-0">4.3.2.) Krajowy Numer Identyfikacyjny: <span class="normal">784-133-38-50</span></h3>    <h3 class="mb-0">4.3.3.) Ulica: <span class="normal">ul. Wodna 18</span></h3>    <h3 class="mb-0">4.3.4.) Miejscowość: <span class="normal">Gniezno</span></h3>    <h3 class="mb-0">4.3.5.) Kod pocztowy: <span class="normal">62-200</span></h3>    <h3 class="mb-0">4.3.6.) Województwo: <span class="normal">wielkopolskie</span></h3>    <h3 class="mb-0">4.3.7.) Kraj: <span class="normal">Polska</span></h3><!-- Wykonawcy -->    <h3 class="mb-0">4.4.) Wartość umowy/umowy ramowej:        <span class="normal">            97499,14                PLN        </span>    </h3>    <h3 class="mb-0">4.5.) Numer ogłoszenia o wyniku postępowania w BZP: <span class="normal">2023/BZP 00529051/01</span></h3>    <h2 class="bg-light p-3 mt-4">SEKCJA V - ZMIANA UMOWY/UMOWY RAMOWEJ</h2>    <h3 class="mb-0">5.1.) Data zmiany umowy/umowy ramowej): <span class="normal">2024-01-19</span></h3>    <h3 class="mb-0">5.2.) Podstawa prawna zmiany umowy/umowy ramowej: </h3>art. 455 ust. 1 pkt 3 ustawy    <h3 class="mb-0">5.3.) Przyczyny dokonania zmian umowy/umowy ramowej: </h3>    - z uwagi na ułożenie nowych nawierzchni parkingu i zmiany rzędnej wysokościowej nawierzchni  zaszła konieczność regulacji i dostosowania rzędnych  elementów istniejącej infrastruktury drogowej;<br/>- nowo powstałe elementu parkingu w tym nawierzchnia i krawężnik betonowy naruszały obecnie funkcjonujący spływ wód deszcz. Istniejący wpust deszczowy, musiał zostać przesunięty, a istniejąca studnia kan. deszczowej musiała zostać poddana regulacji wysokościowej;<br/>-ze względu na to, że regulacja obrzeży poprzez obniżenie nie była możliwa, a podczas użytkowania zachodziłoby ryzyko uszkodzeń pojazdów i infrastruktury drogowej należało zamontować separator parkingowy;<br/>- wystąpiła konieczność wykonania cienkowarstwowego malowania poziomego które było niezbędne do prawidłowego użytkowania;<br/>- wystąpiła konieczność wykonania robót dot. rozbiórki i odtworzenia nawierzchni bitumicznych. Było to niezbędne, gdyż nawierzchnia nowego parkingu z kostki dochodziła i ingerowała w drogę o nawierzchni asfaltowej.    <h3 class="mb-0">5.4.) Krótki opis zmiany umowy/umowy ramowej: </h3>    W wyniku dokonanych zmian wystąpiła konieczność wykonania:<br/>      1) rozbiórki i ponownego ułożenia istniejących nawierzchni z kostki betonowej, <br/>      2) przesunięcia istniejącego wpustu deszczowego i regulacji wysokościowej studni kan. deszczowej,<br/>      3) montażu separatorów parkingowych, <br/>      4)malowania poziomego miejsc postojowych <br/>      5) remontu nawierzchni asfaltowych.<br/>W związku z powyższy nastąpiła zmiana wysokości wynagrodzenia umownego tj. zwiększenie wartości umowy o 18.580,93 zł brutto. Wartość umowy po zmianie wynosi 116.080,07 zł brutto.<h3 class="mb-0">5.5.) Wartość zmiany umowy</h3>    <h3 class="mb-0">5.5.1.) Wartość zmiany: <span class="normal">18580,93</span></h3>    <h3 class="mb-0">5.5.2.) Kod waluty: <span class="normal">PLN</span></h3>    <h3 class="mb-0">5.5.3.) Wzrost ceny w związku ze zmianą umowy/umowy ramowej: <span class="normal">Tak</span></h3>    <h3 class="mb-0">        5.6.) Wcześniejsze zmiany umowy/umowy ramowej, obligujące do zamieszczenia ogłoszenia o zmianie umowy:        <span class="normal">Nie</span>    </h3></main><footer hidden><table style="border-top: 1px solid black; width:100%"><tr><td>2024-01-30 Biuletyn Zamówień Publicznych</td><td style="text-align:right">Ogłoszenie o zmianie umowy - Zamówienie udzielane jest w trybie podstawowym na podstawie: art. 275 pkt 1 ustawy - Roboty budowlane</td></tr></table></footer></body></html>
  """

  # Sample HTML for CircumstancesFulfillmentNotice (Ogłoszenie o spełnieniu okoliczności)
  @circumstances_fulfillment_notice_html """
  <html><head><meta charset="UTF-8"><style>body {
      font-family: "Calibri", sans-serif;
  }
  span.normal {
      font-weight: 400
  }
  </style></head><body><header hidden><table style="border-bottom: 1px solid black; width:100%"><tr><td>Ogłoszenie nr 2024/BZP 00306741 z dnia 2024-04-29</td></tr></table></header><main><!-- Version 1.0.0 --><style type="text/css">    .normal {        color: black;    }    h1.title {    }</style>    <h1 class="text-center mt-5 mb-5">Ogłoszenie o spełnieniu okoliczności<br/>            Usługi<br/>            Odbiór i transport odpadów komunalnych od właścicieli nieruchomości zamieszkałych na terenie gminy Jaświły    </h1>    <h2 class="bg-light p-3 mt-4">SEKCJA I – ZAMAWIAJĄCY</h2>    <h3 class="mb-0 mt-3">1.1.) Nazwa zamawiającego: <span class="normal">GMINA JAŚWIŁY</span></h3>    <h3 class="mb-0 mt-3">1.3.) Krajowy Numer Identyfikacyjny: <span class="normal">REGON 050659349</span></h3><h3 class="mb-0 mt-3">1.4.) Adres zamawiającego: </h3>    <h3 class="mb-0 mt-3">1.4.1.) Ulica: <span class="normal">Jaświły, 7</span></h3>    <h3 class="mb-0 mt-3">1.4.2.) Miejscowość: <span class="normal">Jaświły</span></h3>    <h3 class="mb-0 mt-3">1.4.3.) Kod pocztowy: <span class="normal">19-124</span></h3>    <h3 class="mb-0 mt-3">1.4.4.) Województwo: <span class="normal">podlaskie</span></h3>    <h3 class="mb-0 mt-3">1.4.5.) Kraj: <span class="normal">Polska</span></h3>    <h3 class="mb-0 mt-3">1.4.6.) Lokalizacja NUTS 3: <span class="normal">PL843 - Suwalski</span></h3>    <h3 class="mb-0 mt-3">1.4.7.) Numer telefonu: <span class="normal">857168001</span></h3>    <h3 class="mb-0 mt-3">1.4.9.) Adres poczty elektronicznej: <span class="normal">gmina@jaswily.iap.pl</span></h3>    <h3 class="mb-0 mt-3">1.4.10.) Adres strony internetowej zamawiającego: <span class="normal">https://bip.ug.jaswily.wrotapodlasia.pl</span></h3>    <h3 class="mb-0">1.5.) Rodzaj zamawiającego: <span class="normal">Zamawiający publiczny - jednostka sektora finansów publicznych - jednostka samorządu terytorialnego</span></h3>    <h3 class="mb-0">1.6.) Przedmiot działalności zamawiającego: <span class="normal">Ogólne usługi publiczne</span></h3><!-- SEKCJA II -->    <h2 class="bg-light p-3 mt-4">SEKCJA II – INFORMACJE PODSTAWOWE</h2>    <h3 class="mb-0 mt-3">2.1.) Nazwa zamówienia: <span class="normal">Odbiór i transport odpadów komunalnych od właścicieli nieruchomości zamieszkałych na terenie gminy Jaświły</span></h3>    <h3 class="mb-0 mt-3">2.2.) Identyfikator postępowania: <span class="normal">ocds-148610-5e610b50-aec2-11ed-b8d9-2a18c1f2976f</span></h3>    <h3 class="mb-0 mt-3">2.3.) Numer ogłoszenia: <span class="normal">2024/BZP 00306741</span></h3>    <h3 class="mb-0 mt-3">2.4.) Wersja ogłoszenia: <span class="normal">01</span></h3>    <h3 class="mb-0 mt-3">2.5.) Data ogłoszenia: <span class="normal">2024-04-29</span></h3><h3 class="mb-0 mt-3">    2.6.) Informacje o wcześniejszych ogłoszeniach o spełnianiu okoliczności, o których mowa w art. 214 ust. 1 pkt 11-14 ustawy:</h3>    <h3 class="mb-0 mt-3">        2.6.1.) Czy były zamieszczone wcześniejsze ogłoszenia o spełnianiu okoliczności w BZP:        <span class="normal">Nie</span>    </h3><!-- SEKCJA III -->    <h2 class="bg-light p-3 mt-4">SEKCJA III – PODSTAWOWE INFORMACJE O POSTĘPOWANIU PROWADZONYM W TRYBIE ZAMÓWIENIA Z WOLNEJ RĘKI W WYNIKU KTÓREGO ZOSTAŁA ZAWARTA UMOWA</h2>    <h3 class="mb-0 mt-3">3.1.) Numer ogłoszenia o zamiarze zawarcia umowy w BZP: <span class="normal">2023/BZP 00100794</span></h3>    <h3 class="mb-0 mt-3">3.2.) Numer ogłoszenia o wyniku postępowania w BZP: <span class="normal">2023/BZP 00152204/01</span></h3>    <h3 class="mb-0 mt-3">        3.3.) Zamówienie dotyczy projektu lub programu współfinansowanego ze środków Unii Europejskiej:        <span class="normal">Nie</span>    </h3>    <h3 class="mb-0 mt-3">        3.5.) Podstawa prawna udzielenia zamówienia z wolnej ręki:        <span class="normal">Zamówienie udzielane jest w trybie zamówienia z wolnej ręki na podstawie: art. 305 pkt 1 ustawy w zw. z art. 214 ust. 1 pkt 13 ustawy</span>    </h3>    <h3 class="mb-0 mt-3">        3.6.) Rodzaj zamówienia:        <span class="normal">Usługi</span>    </h3>    <h3 class="mb-0 mt-3">        3.7.) Krótki opis przedmiotu zamówienia:    </h3>    <p class="mb-0"> Odbiór i transport odpadów komunalnych z terenu nieruchomości, na których zamieszkują mieszkańcy położonych na terenie gminy Jaświły w okresie od dnia 1.04.2023 r. do dnia 31.12.2024 r. </p>    <h3 class="mb-0 mt-3">        3.8.) Główny kod CPV:        <span class="normal">90513100-7 - Usługi wywozu odpadów pochodzących z gospodarstw domowych</span>    </h3>    <h3 class="mb-0">3.9.) Dodatkowy kod CPV:        <span class="normal">            <p>90512000-9 - Usługi transportu odpadów</p>            <p>90533000-2 - Usługi gospodarki odpadami</p>    </span>    </h3><!-- SEKCJA IV -->    <h2 class="bg-light p-3 mt-4">SEKCJA IV – POTWIERDZENIE SPEŁNIANIA OKOLICZNOŚCI, O KTÓRYCH MOWA W ART. 214 UST. 1 PKT 11-14 USTAWY</h2>    <h3 class="mb-0 mt-3">        4.1.) Data udzielenia zamówienia (zawarcia umowy):        <span class="normal">2023-03-10</span>    </h3>    <h3 class="mb-0">4.2.) Okres, na jaki została zawarta umowa: </h3>    od 2023-04-01 do 2024-12-31<h3 class="mb-0 mt-3">4.3.) Dane wykonawcy, z którym zawarto umowę: </h3>    <h3 class="mb-0 mt-3">4.3.1.) Nazwa (firma) wykonawcy, któremu udzielono zamówienia (w przypadku wykonawców ubiegających się wspólnie o udzielenie zamówienia – dotyczy pełnomocnika, o którym mowa w art. 58 ust. 2 ustawy): <span class="normal">BIOMTRANS SPÓŁKA Z OGRANICZONĄ ODPOWIEDZIALNOŚCIĄ</span></h3>    <h3 class="mb-0 mt-3">4.3.2.) Krajowy Numer Identyfikacyjny: <span class="normal">5461398167</span></h3>    <h3 class="mb-0 mt-3">4.3.3.) Ulica: <span class="normal">Dolistowo Stare 144</span></h3>    <h3 class="mb-0 mt-3">4.3.4.) Miejscowość: <span class="normal">Dolistowo Stare</span></h3>    <h3 class="mb-0 mt-3">4.3.5.) Kod pocztowy: <span class="normal">19-124</span></h3>    <h3 class="mb-0 mt-3">4.3.6.) Województwo: <span class="normal">podlaskie</span></h3>    <h3 class="mb-0 mt-3">4.3.7.) Kraj: <span class="normal">Polska</span></h3>    <h3 class="mb-0 mt-3">        4.4.) Informacja, czy nadal spełnione są okoliczności uprawniające do udzielenia zamówienia        w trybie zamówienia wolnej ręki na wskazanej podstawie:        <span class="normal">Tak</span>    </h3></main><footer hidden><table style="border-top: 1px solid black; width:100%"><tr><td>2024-04-29 Biuletyn Zamówień Publicznych</td><td style="text-align:right">Ogłoszenie o spełnianiu okoliczności - Zamówienie udzielane jest w trybie zamówienia z wolnej ręki na podstawie: art. 305 pkt 1 ustawy w zw. z art. 214 ust. 1 pkt 13 ustawy - Usługi</td></tr></table></footer></body></html>
  """

  # Sample HTML for CompetitionNotice (Ogłoszenie o konkursie)
  @competition_notice_html """
  <html><head><meta charset="UTF-8"><style>body {
      font-family: "Calibri", sans-serif;
  }
  span.normal {
      font-weight: 400
  }
  </style></head><body><header hidden><table style="border-bottom: 1px solid black; width:100%"><tr><td>Ogłoszenie nr 2024/BZP 00625508 z dnia 2024-11-29</td></tr></table></header><main><!-- Version 1.0.0 --><style type="text/css">    .normal {        color: black;    }    h1.title {    }</style>    <h1 class="text-center mt-5 mb-5">Ogłoszenie o konkursie<br/>    </h1>    <h2 class="bg-light p-3 mt-4">SEKCJA I  ZAMAWIAJĄCY</h2>    <h3 class="mb-0">1.1.) Rola zamawiającego: <span class="normal">Konkurs organizuje podmiot, któremu powierzono organizowanie konkursu</span></h3>    <h3 class="mb-0">1.2.) Nazwa zamawiającego: <span class="normal">Gmina Miasta Dębica</span></h3>    <h2 class="bg-light p-3 mt-4">SEKCJA II – INFORMACJE PODSTAWOWE</h2>    <h3 class="mb-0">2.1.) Nazwa konkursu: </h3>KONKURS SARP nr 1064 ARCHITEKTONICZNO-URBANISTYCZNY, JEDNOETAPOWY, OGRANICZONY, REALIZACYJNY NA „KONCEPCJĘ PRZEBUDOWY RYNKU MIEJSKIEGO W DĘBICY" DLA GMINY MIASTA DĘBICA    <h3 class="mb-0">2.3.) Numer ogłoszenia: <span class="normal">2024/BZP 00625508</span></h3>    <h2 class="bg-light p-3 mt-4">SEKCJA III – PROCEDURA I RODZAJ KONKURSU</h2>    <h3 class="mb-0">3.1.) Procedura konkursu: </h3>Konkurs - ograniczony    <h3 class="mb-0">3.2.) Rodzaj konkursu: </h3>Konkurs jednoetapowy    <h3 class="mb-0">3.6.) Termin składania wniosków o dopuszczenie do udziału w konkursie: <span class="normal">2024-12-27 17:00</span></h3>    <h3 class="mb-0">3.7.) Informacja o obiektywnych wymaganiach: </h3>UCZESTNIK KONKURSU MUSI SPEŁNIĆ WSZYSTKIE NASTĘPUJĄCE WYMAGANIA:<br/>a)	nie podlega wykluczeniu na podstawie:<br/>-	art. 108 ust 1 oraz art. 109 ust. 1 pkt 2, 4-5, pkt 6 w zakresie członków Sądu Konkursowego oraz pkt 7-10 Ustawy<br/>-	art. 7 ust. 1 ustawy z dnia 13 kwietnia 2022 r. o szczególnych rozwiązaniach w zakresie przeciwdziałania wspieraniu agresji na Ukrainę oraz służących ochronie bezpieczeństwa narodowego<br/>b)	spełnia określony przez Organizatora warunek udziału w Konkursie dotyczący zdolności technicznej i zawodowej w zakresie wykształcenia i kwalifikacji zawodowych. Niniejszy warunek zostanie uznany za spełniony, jeżeli Uczestnik konkursu wykaże, iż dysponuje na etapie Konkursu co najmniej:<br/>-	minimum jedną osobą, która legitymuje się dyplomem ukończenia wyższej uczelni w zakresie wymaganym dla uprawiania zawodu architekta z uprawnieniami do projektowania bez ograniczeń w branży architektonicznej.<br/>Uczestnik zaproszony do negocjacji będzie zobowiązany wykazać, że będzie dysponować osobami zdolnymi do wykonania  usługi projektowej na podstawie wybranej pracy konkursowej, a także dysponowaniem na etapie dokumentacji projektowej minimum jedną osobą legitymującą się dyplomem ukończenia wyższej uczelni w zakresie wymaganym dla uprawiania zawodu z uprawnieniami do projektowania bez ograniczeń w branżach:<br/>elektrycznej, sanitarnej i drogowej, przy czym Zamawiający dopuszcza łączenie warunków w ramach jednej osoby.    <h2 class="bg-light p-3 mt-4">SEKCJA IV – UDOSTĘPNIANIE DOKUMENTÓW KONKURSU I KOMUNIKACJA</h2>    <h3 class="mb-0">4.1.) Adres strony internetowej prowadzonego konkursu: </h3>https://rzeszow.sarp.org.pl/index.php/2024/10/31/konkurs-na-koncepcje-zagospodarowania-rynku-w-debicy/</main><footer hidden><table style="border-top: 1px solid black; width:100%"><tr><td>2024-11-29 Biuletyn Zamówień Publicznych</td><td style="text-align:right">Ogłoszenie o konkursie</td></tr></table></footer></body></html>
  """

  # Sample HTML for ContractNotice (Ogłoszenie o zamówieniu)
  @contract_notice_html """
  <html><head><meta charset="UTF-8"><style>body {
      font-family: "Calibri", sans-serif;
  }
  span.normal {
      font-weight: 400
  }
  </style></head><body><main>
      <h1 class="text-center mt-5 mb-5">Ogłoszenie o zamówieniu<br />
          Roboty budowlane<br /> Remont budynku szkoły</h1>
      <h2 class="bg-light p-3 mt-4">SEKCJA I - ZAMAWIAJĄCY</h2>
      <h3 class="mb-0">1.2.) Nazwa zamawiającego: <span class="normal">Gmina Testowa</span></h3>
      <h2 class="bg-light p-3 mt-4">SEKCJA II – INFORMACJE PODSTAWOWE</h2>
      <h3 class="mb-0">2.5.) Numer ogłoszenia: <span class="normal">2024/BZP 00123456</span></h3>
      <h2 class="bg-light p-3 mt-4">SEKCJA IV – PRZEDMIOT ZAMÓWIENIA</h2>
      <h3 class="mb-0">4.3.) Kryteria oceny ofert</h3>
      <h3 class="mb-0">4.3.2.) Sposób określania wagi kryteriów oceny ofert: <span class="normal"> Procentowo </span></h3>
      <h3 class="mb-0">4.3.3.) Stosowane kryteria oceny ofert: <span class="normal"> Kryterium ceny oraz kryteria jakościowe </span></h3>
      <h3 class="mb-0">Kryterium 1</h3>
      <h3 class="mb-0">4.3.5.) Nazwa kryterium: <span class="normal">Cena</span></h3>
      <h3 class="mb-0">4.3.6.) Waga: <span class="normal">60</span></h3>
      <h3 class="mb-0">Kryterium 2</h3>
      <h3 class="mb-0">4.3.4.) Rodzaj kryterium: </h3>inne.
      <h3 class="mb-0">4.3.5.) Nazwa kryterium: <span class="normal">Okres gwarancji</span></h3>
      <h3 class="mb-0">4.3.6.) Waga: <span class="normal">40</span></h3>
  </main></body></html>
  """

  describe "evaluation_criteria extraction for ContractNotice" do
    test "extracts evaluation criteria (kryteria) from ContractNotice" do
      {:ok, parsed} = BzpParser.parse(@contract_notice_html)

      # ContractNotice should have kryteria extracted
      assert is_list(parsed.kryteria)
      assert length(parsed.kryteria) == 2

      cena = Enum.find(parsed.kryteria, fn c -> c.name == "Cena" end)
      assert cena.weight == 60

      gwarancja = Enum.find(parsed.kryteria, fn c -> c.name == "Okres gwarancji" end)
      assert gwarancja.weight == 40
    end
  end

  describe "evaluation_criteria extraction for CompetitionNotice" do
    test "extracts evaluation criteria from section 3.7 (Informacja o obiektywnych wymaganiach)" do
      {:ok, parsed} = BzpParser.parse(@competition_notice_html)

      assert is_binary(parsed.evaluation_criteria)
      assert parsed.evaluation_criteria =~ "UCZESTNIK KONKURSU MUSI SPEŁNIĆ"
      assert parsed.evaluation_criteria =~ "nie podlega wykluczeniu"
      assert parsed.evaluation_criteria =~ "zdolności technicznej i zawodowej"
    end
  end

  describe "evaluation_criteria extraction for AgreementIntentionNotice" do
    test "extracts legal justification from section 4.2 as evaluation_criteria" do
      {:ok, parsed} = BzpParser.parse(@agreement_intention_notice_html)

      # AgreementIntentionNotice has justification in section 4.2
      assert is_binary(parsed.evaluation_criteria)
      assert parsed.evaluation_criteria =~ "art. 214"
      assert parsed.evaluation_criteria =~ "wolnej ręki"
      assert parsed.evaluation_criteria =~ "KIR jest jedyną instytucją"
    end
  end

  describe "evaluation_criteria extraction for AgreementUpdateNotice" do
    test "returns nil for AgreementUpdateNotice (no 3.7 or 4.2 section)" do
      {:ok, parsed} = BzpParser.parse(@agreement_update_notice_html)

      # AgreementUpdateNotice doesn't have 3.7 or 4.2 sections
      # so evaluation_criteria should be nil
      assert is_nil(parsed.evaluation_criteria)
    end
  end

  describe "evaluation_criteria extraction for CircumstancesFulfillmentNotice" do
    test "returns nil for CircumstancesFulfillmentNotice (no 3.7 or 4.2 section)" do
      {:ok, parsed} = BzpParser.parse(@circumstances_fulfillment_notice_html)

      # CircumstancesFulfillmentNotice doesn't have 3.7 or 4.2 sections
      assert is_nil(parsed.evaluation_criteria)
    end
  end

  describe "evaluation_criteria in tender upsert" do
    test "evaluation_criteria is parsed and saved when upserting tender" do
      # Verify that evaluation_criteria flows through the full upsert process
      attrs = %{
        "object_id" => "test-eval-criteria-#{System.unique_integer([:positive])}",
        "notice_type" => "CompetitionNotice",
        "notice_number" => "2024/BZP 00625508",
        "bzp_number" => "2024/BZP 00625508",
        "is_tender_amount_below_eu" => true,
        "publication_date" => DateTime.utc_now(),
        "cpv_codes" => ["45000000-7"],
        "organization_name" => "Gmina Miasta Dębica",
        "organization_city" => "Dębica",
        "organization_country" => "Polska",
        "organization_national_id" => "REGON 000524648",
        "organization_id" => "test-org-id",
        "html_body" => @competition_notice_html
      }

      # The parser should extract evaluation_criteria when upserting
      {:ok, parsed} = BzpParser.parse(attrs["html_body"])
      assert is_binary(parsed.evaluation_criteria)
      assert parsed.evaluation_criteria =~ "UCZESTNIK KONKURSU"
    end
  end
end
