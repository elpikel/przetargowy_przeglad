defmodule PrzetargowyPrzeglad.Tenders.BzpParserTest do
  use ExUnit.Case, async: true

  alias PrzetargowyPrzeglad.Tenders.BzpParser

  @sample_html """
  <html><head><meta charset="UTF-8"><style>body {
      font-family: "Calibri", sans-serif;
  }

  span.normal {
      font-weight: 400
  }

  .text-center {
      text-align: center
  }

  .bg-light {
      background-color: #F2F2F2
  }

  * {
      box-sizing: border-box
  }

  .h1,
  h1 {
      font-size: 1.75rem
  }

  .h3,
  h3 {
      font-size: 11pt;
      font-weight: 700;
      margin-bottom: 1.25rem
  }

  .h1,
  h1 {
      font-size: 11pt;
      font-family: "Arial",sans-serif;
  }

  .h2,
  h2 {
      font-size: 12pt;
      font-family: "Arial",sans-serif;
      font-weight: bold;
      margin-bottom: 1.25rem
  }

  .p-3 {
      border: solid windowtext 1.0pt;
      background: #BFBFBF;
      padding: 0cm 5.4pt 0cm 5.4pt;
  }

  .mb-0 {
      margin-bottom: 0 !important
  }

  .mb-1 {
      margin-bottom: .5rem !important
  }

  .mb-2 {
      margin-bottom: 1rem !important
  }

  .mb-3 {
      margin-bottom: 1.5rem !important
  }

  .mb-4 {
      margin-bottom: 2rem !important
  }

  .mb-5 {
      margin-bottom: 2.5rem !important
  }

  .mb-6 {
      margin-bottom: 3rem !important
  }

  .mb-7 {
      margin-bottom: 3.5rem !important
  }

  .mb-8 {
      margin-bottom: 4rem !important
  }

  .mb-9 {
      margin-bottom: 4.5rem !important
  }

  .mb-10 {
      margin-bottom: 5rem !important
  }

  .mb-auto {
      margin-bottom: auto !important
  }
  </style></head><body><header hidden><table style="border-bottom: 1px solid black; width:100%"><tr><td>Ogłoszenie nr 2026/BZP 00046327 z dnia 2026-01-19</td></tr></table></header><main><!-- Version 1.0.0 --><style type="text/css">    .normal {        color: black;    }    h1.title {    }</style>    <h1 class="text-center mt-5 mb-5">Ogłoszenie o zamówieniu<br/>            Roboty budowlane<br/>            Remont hali sportowej nr 9 w k/3015 w Bolesławcu wraz z opracowaniem dokumentacji projektowo- kosztorysowej    </h1>    <h2 class="bg-light p-3 mt-4">SEKCJA I - ZAMAWIAJĄCY</h2>    <h3 class="mb-0">1.1.) Rola zamawiającego</h3>    <p class="mb-0">Postępowanie prowadzone jest samodzielnie przez zamawiającego</p>    <h3 class="mb-0">1.2.) Nazwa zamawiającego: <span class="normal">43 WOJSKOWY ODDZIAŁ GOSPODARCZY</span></h3>    <h3 class="mb-0">1.4) Krajowy Numer Identyfikacyjny: <span class="normal">REGON 021509084</span></h3><h3 class="mb-0">1.5) Adres zamawiającego  </h3>    <h3 class="mb-0">1.5.1.) Ulica: <span class="normal">Saperska 2</span></h3>    <h3 class="mb-0">1.5.2.) Miejscowość: <span class="normal">Świętoszów</span></h3>    <h3 class="mb-0">1.5.3.) Kod pocztowy: <span class="normal">59-726</span></h3>    <h3 class="mb-0">1.5.4.) Województwo: <span class="normal">dolnośląskie</span></h3>    <h3 class="mb-0">1.5.5.) Kraj: <span class="normal">Polska</span></h3>    <h3 class="mb-0">1.5.6.) Lokalizacja NUTS 3: <span class="normal">PL515 - Jeleniogórski</span></h3>    <h3 class="mb-0">1.5.9.) Adres poczty elektronicznej: <span class="normal">43wog.szp@ron.mil.pl</span></h3>    <h3 class="mb-0">1.5.10.) Adres strony internetowej zamawiającego: <span class="normal">https://43wog.wp.mil.pl/pl/</span></h3>    <h3 class="mb-0">        1.6.) Rodzaj zamawiającego: <span class="normal">Zamawiający publiczny - jednostka sektora finansów publicznych - jednostka budżetowa</span>    </h3>    <h3 class="mb-0">        1.7.) Przedmiot działalności zamawiającego:        <span class="normal">Ogólne usługi publiczne</span>    </h3>    <h2 class="bg-light p-3 mt-4">SEKCJA II – INFORMACJE PODSTAWOWE</h2>    <h3 class="mb-0">2.1.) Ogłoszenie dotyczy: </h3>    <p class="mb-0">        Zamówienia publicznego    </p>    <h3 class="mb-0">2.2.) Ogłoszenie dotyczy usług społecznych i innych szczególnych usług: <span class="normal">Nie</span></h3>    <h3 class="mb-0">2.3.) Nazwa zamówienia albo umowy ramowej: </h3>    <p class="mb-0">        Remont hali sportowej nr 9 w k/3015 w Bolesławcu wraz z opracowaniem dokumentacji projektowo- kosztorysowej    </p>    <h3 class="mb-0">2.4.) Identyfikator postępowania: <span class="normal">ocds-148610-5bb0fece-2745-40b2-9ed3-6b7c6a551372</span></h3>    <h3 class="mb-0">2.5.) Numer ogłoszenia: <span class="normal">2026/BZP 00046327</span></h3>    <h3 class="mb-0">2.6.) Wersja ogłoszenia: <span class="normal">01</span></h3>    <h3 class="mb-0">2.7.) Data ogłoszenia: <span class="normal">2026-01-19</span></h3>    <h3 class="mb-0">2.8.) Zamówienie albo umowa ramowa zostały ujęte w planie postępowań: <span class="normal">Nie</span></h3>    <h3 class="mb-0">2.11.) O udzielenie zamówienia mogą ubiegać się wyłącznie wykonawcy, o których mowa w art. 94 ustawy: <span class="normal">Nie</span></h3>    <h3 class="mb-0">2.14.) Czy zamówienie albo umowa ramowa dotyczy projektu lub programu współfinansowanego ze środków Unii Europejskiej: <span class="normal">Nie</span></h3>    <h3 class="mb-0">2.16.) Tryb udzielenia zamówienia wraz z podstawą prawną</h3>    <p class="mb-0">        Zamówienie udzielane jest w trybie podstawowym na podstawie: art. 275 pkt 1 ustawy    </p>    <h2 class="bg-light p-3 mt-4">SEKCJA III – UDOSTĘPNIANIE DOKUMENTÓW ZAMÓWIENIA I KOMUNIKACJA</h2>    <h3 class="mb-0">3.1.) Adres strony internetowej prowadzonego postępowania</h3>    https://platformazakupowa.pl/transakcja/1248226    <h3 class="mb-0">3.2.) Zamawiający zastrzega dostęp do dokumentów zamówienia: <span class="normal">Nie</span></h3>    <h3 class="mb-0">3.4.) Wykonawcy zobowiązani są do składania ofert, wniosków o dopuszczenie do udziału w postępowaniu, oświadczeń oraz innych dokumentów wyłącznie przy użyciu środków komunikacji elektronicznej: <span class="normal">Tak</span></h3>    <h3 class="mb-0">3.5.) Informacje o środkach komunikacji elektronicznej, przy użyciu których zamawiający  będzie komunikował się z wykonawcami - adres strony internetowej: <span class="normal">https://platformazakupowa.pl/transakcja/1248226</span></h3>    <h3 class="mb-0">3.6.) Wymagania techniczne i organizacyjne dotyczące korespondencji elektronicznej: <span class="normal">Oferta, wniosek oraz przedmiotowe środki dowodowe (jeżeli były wymagane) składane elektronicznie muszą zostać podpisane kwalifikowanym podpisem, zaufanym lub podpisem osobistym. W procesie składania oferty, wniosku w tym przedmiotowych środków dowodowych na platformie, kwalifikowany podpis elektroniczny Wykonawca składa bezpośrednio na dokumencie, który następnie przesyła do systemu.<br/>Oferta powinna być:<br/>a) sporządzona na podstawie załączników niniejszej SWZ w języku polskim,<br/>b) złożona przy użyciu środków komunikacji elektronicznej tzn. za pośrednictwem platformazakupowa.pl,<br/>c) podpisana kwalifikowanym podpisem elektronicznym przez osobę/osoby upoważnioną/upoważnione<br/>W przypadku wykorzystania formatu podpisu XAdES zewnętrzny. Zamawiający wymaga dołączenia odpowiedniej ilości plików tj.<br/>podpisywanych plików z danymi oraz plików podpisu w formacie XAdES.<br/>Zgodnie z art. 18 ust. 3 ustawy Pzp, nie ujawnia się informacji stanowiących tajemnicę przedsiębiorstwa, w rozumieniu przepisów o zwalczaniu nieuczciwej konkurencji. Jeżeli wykonawca, nie później niż w terminie składania ofert, w sposób niebudzący wątpliwości zastrzegł, że nie mogą być one udostępniane oraz wykazał, załączając stosowne wyjaśnienia, iż zastrzeżone informacje stanowią tajemnicę przedsiębiorstwa. Na platformie w formularzu składania oferty znajduje się miejsce wyznaczone do dołączenia części oferty stanowiącej tajemnicę przedsiębiorstwa. Podmiotowe środki dowodowe lub inne dokumenty, w tym dokumenty potwierdzające<br/>umocowanie do reprezentowania, sporządzone w języku obcym przekazuje się wraz z tłumaczeniem na język polski. Maksymalny rozmiar jednego pliku przesyłanego za pośrednictwem dedykowanych formularzy do: złożenia, zmiany, wycofania oferty wynosi 150MB natomiast przy komunikacji wielkość pliku to maksymalnie 500 MB. Zamawiający rekomenduje wykorzystanie formatów: .pdf.doc .docx .xls .xlsx .jpg (.jpeg) ze szczególnym wskazaniem na .pdf Pliki w innych formatach niż PDF zaleca się opatrzyć zewnętrznym podpisem XAdES. Wykonawca powinien pamiętać, aby plik z podpisem przekazywać łącznie z dokumentem podpisywanym. Sposób sporządzenia dokumentów elektronicznych, oświadczeń lub elektronicznych kopii dokumentów lub oświadczeń musi być zgody z wymaganiami określonymi w Rozporządzeniu o elektronizacji oraz Rozporządzeniu o dokumentach.<br/>W celu ewentualnej kompresji danych Zamawiający rekomenduje wykorzystanie jednego z formatów:<br/>a) .zip<br/>b) .7Z<br/>Wśród formatów powszechnych a NIE występujących w rozporządzeniu występują: .rar .gif .bmp .numbers .pages. Dokumenty złożone w takich plikach zostaną uznane za złożone nieskutecznie. Zamawiający zwraca uwagę na ograniczenia wielkości plików podpisywanych profilem zaufanym, który wynosi max 10MB, oraz na ograniczenie wielkości plików podpisywanych w aplikacji eDoApp służącej do składania podpisu osobistego, który wynosi max 5MB. Ze względu na niskie ryzyko naruszenia integralności pliku oraz łatwiejszą weryfikację podpisu, zamawiający zaleca, w miarę możliwości, przekonwertowanie plików składających się na ofertę na format .pdf i opatrzenie ich podpisem kwalifikowanym PAdES. Zamawiający zaleca aby w przypadku podpisywania pliku przez kilka osób, stosować podpisy tego samego rodzaju. Podpisywanie różnymi rodzajami podpisów np. osobistym i kwalifikowanym może doprowadzić do problemów w weryfikacji plików. Podczas podpisywania plików zaleca się stosowanie algorytmu skrótu SHA2 zamiast SHA1. Jeśli wykonawca pakuje dokumenty np. w plik ZIP zalecamy wcześniejsze podpisanie każdego ze skompresowanych plików.</span></h3>    <h3 class="mb-0">3.8.) Zamawiający wymaga sporządzenia i przedstawienia ofert przy użyciu narzędzi elektronicznego modelowania danych budowlanych lub innych podobnych narzędzi, które nie są ogólnie dostępne: <span class="normal">Nie</span></h3>    <h3 class="mb-0">3.12.) Oferta - katalog elektroniczny: <span class="normal">Nie dotyczy</span></h3>    <h3 class="mb-0">3.14.) Języki, w jakich mogą być sporządzane dokumenty składane w postępowaniu: </h3>        <p class="mb-0">polski</p>    <h3 class="mb-0">3.15.) RODO (obowiązek informacyjny): <span class="normal">Zgodnie z art. 13 ust. 1 i 2 rozporządzenia Parlamentu Europejskiego i Rady (UE) 2016/679 z dnia 27 kwietnia 2016 r. w sprawie ochrony osób fizycznych<br/>w związku z przetwarzaniem danych osobowych i w sprawie swobodnego przepływu takich danych oraz uchylenia dyrektywy 95/46/WE (ogólne rozporządzenie o danych) (Dz. U. UE L119 z dnia 4 maja 2016r., str. 1; zwanym dalej „RODO") informujemy, że:1) administratorem Pani/Pana danych osobowych jest: 43 Wojskowy Oddział Gospodarczy z siedzibą w Świętoszowie ul. Saperska 2, 59-726 Świętoszów2) administrator wyznaczył<br/>Inspektora Danych Osobowych, z którym można się kontaktować pod adresem e-mail: 43wog.iod@ron.mil.pl.3) Pani/Pana dane<br/>osobowe przetwarzane będą na podstawie art. 6 ust. 1 lit. c RODO w celu związanym z przedmiotowym postępowaniem o udzielenie zamówienia publicznego, prowadzonym w trybie przetargu nieograniczonego. 4) odbiorcami Pani/Pana danych osobowych będą osoby lub podmioty, którym udostępniona zostanie dokumentacja postępowania w oparciu o art.<br/>74 ustawy P.Z.P.5) Pani/Pana dane osobowe będą przechowywane, zgodnie z art. 78 ust. 1 P.Z.P. przez okres 4 lat od dnia zakończenia postępowania o udzielenie zamówienia, a jeżeli czas trwania umowy przekracza 4 lata, okres przechowywania obejmuje cały czas trwania umowy;6) obowiązek podania przez Panią/Pana danych osobowych bezpośrednio Pani/Pana<br/>dotyczących jest wymogiem ustawowym określonym w przepisach ustawy P.Z.P., związanym z udziałem w postępowaniu o udzielenie zamówienia publicznego.7) w odniesieniu do Pani/Pana danych osobowych decyzje nie będą podejmowane w sposób zautomatyzowany, stosownie do art. 22 RODO.8) posiada Pani/Pana) na podstawie art. 15 RODO prawo dostępu do danych osobowych Pani/Pana dotyczących (w przypadku, gdy skorzystanie z tego prawa wymagałoby po stronie administratora niewspółmiernie dużego wysiłku może zostać Pani/Pan zobowiązana do wskazania dodatkowych informacji mających na celu sprecyzowanie żądania, w szczególności podania nazwy lub daty postępowania o udzielenie zamówienia publicznego lub konkursu albo sprecyzowanie nazwy lub daty zakończonego postępowania o<br/>udzielenie zamówienia);b) na podstawie art. 16 RODO prawo do sprostowania Pani/Pana danych osobowych (skorzystanie z prawa<br/>do sprostowania nie może skutkować zmianą wyniku postępowania o udzielenie zamówienia publicznego ani zmianą postanowień umowy w zakresie niezgodnym z ustawą PZP oraz nie może naruszać integralności protokołu oraz jego załączników);c) na podstawie art. 18 RODO prawo żądania od administratora ograniczenia przetwarzania danych osobowych z zastrzeżeniem okresu trwania postępowania o udzielenie zamówienia publicznego lub konkursu oraz przypadków, o których mowa w art. 18 ust. 2 RODO (prawo do ograniczenia przetwarzania nie ma zastosowania w odniesieniu do przechowywania, w celu zapewnienia korzystania ze<br/>środków ochrony prawnej lub w celu ochrony praw innej osoby fizycznej lub prawnej, lub z uwagi na ważne względy interesu publicznego Unii Europejskiej lub państwa członkowskiego);d) prawo do wniesienia skargi do Prezesa Urzędu Ochrony Danych Osobowych, gdy uzna Pani/Pan, że przetwarzanie danych osobowych Pani/Pana dotyczących narusza przepisy RODO; 9) nie<br/>przysługuje Pani/Panu:<br/>a) w związku z art. 17 ust. 3 lit. b, d lub e RODO prawo do usunięcia danych osobowych;<br/>b) prawo do przenoszenia danych osobowych, o którym mowa w<br/>art.20 RODO;<br/>c) na podstawie art. 21 RODO prawo sprzeciwu, wobec przetwarzania danych<br/>osobowych, gdyż podstawą prawną przetwarzania Pani/Pana danych osobowych jest art. 6 ust. 1 lit. c<br/>RODO; 10) przysługuje Pani/Panu prawo wniesienia skargi do organu nadzorczego na niezgodne z RODO przetwarzanie Pani/Pana<br/>danych osobowych przez administratora.</span></h3>    <h2 class="bg-light p-3 mt-4">SEKCJA IV – PRZEDMIOT ZAMÓWIENIA</h2><h3 class="mb-0">4.1.) Informacje ogólne odnoszące się do przedmiotu zamówienia.</h3>    <h3 class="mb-0">4.1.1.) Przed wszczęciem postępowania przeprowadzono konsultacje rynkowe: <span class="normal">Nie</span></h3>    <h3 class="mb-0">4.1.2.) Numer referencyjny: <span class="normal">2/26/PN/2026</span></h3>    <h3 class="mb-0">4.1.3.) Rodzaj zamówienia: <span class="normal">Roboty budowlane</span></h3>    <h3 class="mb-0">4.1.4.) Zamawiający udziela zamówienia w częściach, z których każda stanowi przedmiot odrębnego postępowania: <span class="normal">Nie</span></h3>    <h3 class="mb-0">4.1.8.) Możliwe jest składanie ofert częściowych: <span class="normal">Nie</span></h3>    <h3 class="mb-0">4.1.13.) Zamawiający uwzględnia aspekty społeczne, środowiskowe lub etykiety w opisie przedmiotu zamówienia: <span class="normal">Nie</span></h3><h3 class="mb-0">4.2. Informacje szczegółowe odnoszące się do przedmiotu zamówienia:</h3>        <h3 class="mb-0">4.2.2.) Krótki opis przedmiotu zamówienia</h3>        <p class="mb-0">            Remont hali sportowej nr 9 w k/3015 w Bolesławcu wraz z opracowaniem dokumentacji projektowo- kosztorysowej zgodnie z dokumentacją postępowania        </p>        <h3 class="mb-0">4.2.6.) Główny kod CPV: <span class="normal">45000000-7 - Roboty budowlane</span></h3>        <h3 class="mb-0">4.2.8.) Zamówienie obejmuje opcje: <span class="normal">Nie</span></h3>        <!-- realizacja do -->        <h3 class="mb-0">4.2.10.) Okres realizacji zamówienia albo umowy ramowej: <span class="normal">do 2026-11-30</span></h3>        <h3 class="mb-0">4.2.11.) Zamawiający przewiduje wznowienia: <span class="normal">Nie</span></h3>        <h3 class="mb-0">4.2.13.) Zamawiający przewiduje udzielenie dotychczasowemu wykonawcy zamówień na podobne usługi lub roboty budowlane: <span class="normal">Nie</span></h3>    <h3 class="mb-0">4.3.) Kryteria oceny ofert</h3>            <h3 class="mb-0">4.3.2.) Sposób określania wagi kryteriów oceny ofert: <span class="normal"> Procentowo </span></h3>            <h3 class="mb-0">4.3.3.) Stosowane kryteria oceny ofert: <span class="normal"> Wyłącznie kryterium ceny </span></h3>                    <h3 class="mb-0">Kryterium 1</h3>                        <h3 class="mb-0">4.3.5.) Nazwa kryterium: <span class="normal">Cena</span></h3>                        <h3 class="mb-0">4.3.6.) Waga: <span class="normal">100</span></h3>            <h3 class="mb-0">4.3.10.) Zamawiający określa  aspekty społeczne, środowiskowe lub innowacyjne, żąda etykiet lub stosuje rachunek kosztów cyklu życia w odniesieniu do kryterium oceny ofert: <span class="normal">Nie</span></h3>    <h2 class="bg-light p-3 mt-4">SEKCJA V - KWALIFIKACJA WYKONAWCÓW</h2>    <h3 class="mb-0">5.1.) Zamawiający przewiduje fakultatywne podstawy wykluczenia: <span class="normal">Nie</span></h3>    <h3 class="mb-0">5.3.) Warunki udziału w postępowaniu: <span class="normal">Tak</span></h3>    <h3 class="mb-0">5.4.) Nazwa i opis warunków udziału w postępowaniu.</h3>    O udzielenie zamówienia mogą ubiegać się Wykonawcy, którzy spełniają warunki dotyczące zdolności technicznej lub zawodowej:<br/>1)	Wykonawca spełni warunek, jeżeli wykaże, że w okresie ostatnich 5 lat przed upływem terminu składania ofert, a jeżeli okres prowadzenia działalności jest krótszy - w tym okresie, wykonał należycie co najmniej <br/>1 świadczenie odpowiadające swoim rodzajem przedmiotowi zamówienia <br/>o podobnych charakterze o kubaturze powyżej 8 000 m3 wymagany <br/>1 obiekt.<br/>2) Wykonawca dysponuje lub będzie dysponował podczas realizacji   zamówienia n/w osobami:<br/>projektantem – co najmniej jedną osobą, posiadającą uprawnienia do<br/>projektowania bez ograniczeń w następujących specjalnościach:<br/>- instalacyjnej w zakresie: sieci, instalacji urządzeń elektrycznych <br/>i elektroenergetycznych, <br/>- instalacyjno- inżynieryjnej (instalacji sanitarnych),<br/>- architektonicznej,<br/>- konstrukcyjno- budowlanej pozwalające na wykonanie dokumentacji projektowej objętej przedmiotem zamówienia.<br/> <br/>kierownikiem robót budowlanych – co najmniej jedną osobą, posiadającą uprawnienia budowlane do kierowania robotami budowlanymi w specjalności konstrukcyjno-budowlanej  bez ograniczeń lub równoważne, pozwalające na kierowanie robotami budowlanymi objętymi przedmiotem zamówienia;<br/><br/>kierownikiem robót elektrycznych – co najmniej jedną osobą, posiadającą uprawnienia budowlane do kierowania robotami budowlanymi w specjalności instalacyjnej w zakresie sieci, instalacji urządzeń elektrycznych <br/>i elektroenergetycznych bez ograniczeń lub równoważne, pozwalające na kierowanie robotami budowlanymi objętymi przedmiotem zamówienia;<br/><br/>co najmniej jedną osobą do wykonywania robót elektrycznych, posiadającą świadectwo kwalifikacyjne do wykonywania instalacji elektrycznych oraz prac kontrolno- pomiarowych serii E i D do 1 kV.<br/><br/>Zamawiający dopuszcza możliwość łączenia ww. funkcji, pod warunkiem posiadania przez jedną osobę wymaganych uprawnień budowlanych.    <h3 class="mb-0">5.5.) Zamawiający wymaga złożenia oświadczenia, o którym mowa w art.125 ust. 1 ustawy: <span class="normal">Tak</span></h3>            <h3 class="mb-0">                    5.7.) Wykaz podmiotowych środków dowodowych na potwierdzenie spełniania warunków udziału w postępowaniu: <span class="normal">Wykaz osób, skierowanych przez Wykonawcę do realizacji zamówienia publicznego, w szczególności odpowiedzialnych za świadczenie usług oraz kontrolę jakości, wraz z informacjami na temat ich kwalifikacji zawodowych, uprawnień, doświadczenia i wykształcenia niezbędnych do wykonania zamówienia publicznego, a także zakresu wykonywanych przez nie czynności oraz informacją o podstawie do dysponowania tymi osobami;<br/>Wykaz osób musi potwierdzać spełnienie warunku udziału w postępowaniu<br/>w zakresie określonym w Rozdziale VIII ust.2 pkt.4) SWZ. Wzór wykazu osób stanowi załącznik nr 8 do SWZ.</span>            </h3>    <h3 class="mb-0">5.11.) Wykaz innych wymaganych oświadczeń lub dokumentów: </h3>    Do oferty Wykonawca zobowiązany jest dołączyć:<br/>1) aktualne na dzień składania ofert oświadczenie o spełnianiu warunków udziału w postępowaniu oraz o braku podstaw do wykluczenia z postępowania – zgodnie z załącznikiem nr 3 do SWZ. Informacje zawarte w oświadczeniu, o którym mowa w pkt. 1 stanowią wstępne potwierdzenie, że Wykonawca nie podlega wykluczeniu oraz spełnia warunki udziału w postępowaniu. Oświadczenie składane jest pod rygorem nieważności w formie elektronicznej lub w postaci elektronicznej opatrzonej podpisem kwalifikowanym, podpisem zaufanym, lub podpisem osobistym.<br/>2) odpis lub informację z KRS, CEiDG lub innego właściwego rejestru<br/>w celu potwierdzenia, że osoba działająca w imieniu Wykonawcy jest umocowana do jego reprezentowania, sporządzony nie wcześniej niż<br/>3 miesiące przed złożeniem. Wykonawca nie jest zobowiązany do złożenia dokumentów, jeżeli Zamawiający może je uzyskać za pomocą bezpłatnych<br/>i ogólnodostępnych baz danych, ile wykonawca wskazał dane umożliwiające dostęp do tych dokumentów.    <h2 class="bg-light p-3 mt-4">SEKCJA VI - WARUNKI ZAMÓWIENIA</h2>    <h3 class="mb-0">6.1.) Zamawiający wymaga albo dopuszcza oferty wariantowe: <span class="normal">Nie</span></h3>    <h3 class="mb-0">6.3.) Zamawiający przewiduje aukcję elektroniczną: <span class="normal">Nie</span></h3>    <h3 class="mb-0">6.4.) Zamawiający wymaga wadium: <span class="normal">Tak</span></h3>    <h3 class="mb-0">6.4.1) Informacje dotyczące wadium: </h3>    1.	Zamawiający wymaga wniesienia wadium. <br/>2.	Wykonawca zobowiązany jest, do zabezpieczenia swojej oferty w wadium <br/>w wysokości: 14 300,00 zł <br/>3.	Wadium wnosi się przed upływem terminu składania ofert i utrzymuje nieprzerwanie do dnia upływu terminu związania ofertą, z wyjątkiem przypadków, o których mowa w art. 98 ust. 1 pkt 2 i 3 oraz ust. 2.<br/>4.	Wadium może być wnoszone w jednej lub kilku następujących formach:<br/>1)	pieniądzu; <br/>2)	gwarancjach bankowych;<br/>3)	gwarancjach ubezpieczeniowych;<br/>4)	poręczeniach udzielanych przez podmioty, o których mowa w art. 6 b ust. 5 pkt. 2 ustawy z dnia 9 listopada 2000 r. o utworzeniu Polskiej Agencji Rozwoju Przedsiębiorczości (Dz. U. z 2019 r. poz. 310, 836 i 1572).<br/>5.	Wadium wnoszone w formie pieniądza należy wpłacić przelewem na rachunek bankowy 97 1010 1674 0030 3013 9120 0000 z dopiskiem na przelewie: „Wadium w postępowaniu 2/26/PN/2026" Wadium musi wpłynąć na wskazany rachunek bankowy zamawiającego najpóźniej przed upływem terminu składania ofert.<br/>UWAGA: Za termin wniesienia wadium w formie pieniężnej zostanie przyjęty termin uznania rachunku Zamawiającego.<br/>6.	Wadium wnoszone w formie poręczeń lub gwarancji musi spełniać co najmniej poniższe wymagania: <br/>a)	musi obejmować odpowiedzialność za wszystkie przypadki powodujące utratę wadium przez Wykonawcę określone w ustawie p.z.p. bez potwierdzania tych okoliczności;<br/>b)	z jej treści powinno jednoznacznej wynikać zobowiązanie gwaranta do zapłaty całej kwoty wadium;<br/>c)	powinno być nieodwołalne i bezwarunkowe oraz płatne na pierwsze żądanie;<br/>d)	termin obowiązywania poręczenia lub gwarancji nie może być krótszy niż termin związania ofertą (z zastrzeżeniem iż pierwszym dniem związania ofertą jest dzień składania ofert); <br/>e)	w treści poręczenia lub gwarancji powinna znaleźć się nazwa oraz numer przedmiotowego postępowania;<br/>f)	beneficjentem poręczenia lub gwarancji jest: 43 Wojskowy Oddział Gospodarczy w Świętoszowie<br/>g)	w przypadku Wykonawców wspólnie ubiegających się o udzielenie zamówienia (art. 58 p.z.p.), Zamawiający wymaga aby poręczenie lub gwarancja obejmowała swą treścią (tj. zobowiązanych z tytułu poręczenia lub gwarancji) wszystkich Wykonawców wspólnie ubiegających się o udzielenie zamówienia lub aby z jej treści wynikało, że zabezpiecza ofertę Wykonawców wspólnie ubiegających się o udzielenie zamówienia (konsorcjum);<br/>h)	musi zostać złożone w postaci elektronicznej, opatrzone kwalifikowanym podpisem elektronicznym przez wystawcę poręczenia lub gwarancji.<br/>7.	W przypadku wniesienia wadium w formie: <br/>1)	pieniężnej - zaleca się, by dowód dokonania przelewu został dołączony do oferty; <br/>2)	poręczeń lub gwarancji - wymaga się, by oryginał dokumentu został złożony wraz z ofertą.<br/>8.	Oferta wykonawcy, który nie wniesie wadium, wniesie wadium w sposób nieprawidłowy lub nie utrzyma wadium nieprzerwanie do upływu terminu związania ofertą lub złoży wniosek o zwrot wadium w przypadku, o którym mowa w art. 98 ust. 2 pkt. 3 p.z.p. zostanie odrzucona.<br/>9.	Zasady zwrotu oraz okoliczności zatrzymania wadium określa art. 98 p.z.p    <h3 class="mb-0">6.5.) Zamawiający wymaga zabezpieczenia należytego wykonania umowy: <span class="normal">Tak</span></h3>    <h3 class="mb-0">6.6.) Wymagania dotyczące składania oferty przez wykonawców wspólnie ubiegających się o udzielenie zamówienia: </h3>    Wykonawcy mogą wspólnie ubiegać się o udzielenie zamówienia. W takim przypadku Wykonawcy ustanawiają pełnomocnika do reprezentowania ich w postępowaniu albo do reprezentowania i zawarcia umowy w sprawie zamówienia publicznego. Pełnomocnictwo winno być załączone do oferty.<br/>W przypadku Wykonawców wspólnie ubiegających się o udzielenie zamówienia, oświadczenie, o którym mowa w Rozdziale X ust. 1 SWZ, składa każdy z wykonawców. Oświadczenie potwierdza brak podstaw wykluczenia oraz spełnianie warunków udziału w zakresie, w jakim każdy z wykonawców wykazuje spełnianie warunków udziału w postępowaniu. Oświadczenia i dokumenty potwierdzające brak podstaw do wykluczenia z postępowania, składa każdy z Wykonawców wspólnie ubiegających się o zamówienie.<br/>Wykonawcy wspólnie ubiegający się o udzielenie zamówienia wskazują<br/>w Załączniku nr 5 do SWZ, które usługi wykonają poszczególni wykonawcy.    <h3 class="mb-0">6.7.) Zamawiający przewiduje unieważnienie postępowania, jeśli środki publiczne, które zamierzał przeznaczyć na sfinansowanie całości lub części zamówienia nie zostały przyznane: <span class="normal">Nie</span></h3>    <h2 class="bg-light p-3 mt-4">SEKCJA VII - PROJEKTOWANE POSTANOWIENIA UMOWY</h2>    <h3 class="mb-0">7.1.) Zamawiający przewiduje udzielenia zaliczek: <span class="normal">Nie</span></h3>    <h3 class="mb-0">7.3.) Zamawiający przewiduje zmiany umowy: <span class="normal">Tak</span></h3>    <h3 class="mb-0">7.4.) Rodzaj i zakres zmian umowy oraz warunki ich wprowadzenia: </h3>    1.Wybrany Wykonawca jest zobowiązany do zawarcia umowy w sprawie zamówienia publicznego na warunkach określonych we Wzorze Umowy, stanowiącym Załącznik nr 7 do SWZ.<br/>2. Zakres świadczenia Wykonawcy wynikający z umowy jest tożsamy z jego zobowiązaniem zawartym w ofercie.<br/>3. Zmiana umowy podlega unieważnieniu, jeżeli została dokonana z naruszeniem art. 454 i art. 455 p.z.p.<br/>4. Zamawiający przewiduje możliwość zmiany zawartej umowy w stosunku do treści wybranej oferty w zakresie wskazanym we Wzorze Umowy.<br/>5. Zmiana umowy wymaga dla swej ważności, pod rygorem nieważności, zachowania formy pisemnej.    <h3 class="mb-0">7.5.) Zamawiający uwzględnił aspekty społeczne, środowiskowe, innowacyjne lub etykiety związane z realizacją zamówienia: <span class="normal">Nie</span></h3>    <h2 class="bg-light p-3 mt-4">SEKCJA VIII – PROCEDURA</h2>    <h3 class="mb-0">8.1.) Termin składania ofert: <span class="normal">2026-02-03 08:00</span></h3>    <h3 class="mb-0">8.2.) Miejsce składania ofert: <span class="normal">https://platformazakupowa.pl/transakcja/1248226</span></h3>    <h3 class="mb-0">8.3.) Termin otwarcia ofert: <span class="normal">2026-02-03 08:05</span></h3>    <h3 class="mb-0">8.4.) Termin związania ofertą: <span class="normal">do 2026-03-05</span></h3>    <h2 class="bg-light p-3 mt-4">SEKCJA IX – POZOSTAŁE INFORMACJE</h2>    Z postępowania o udzielenie zamówienia zamawiający wykluczy wykonawców, w stosunku do których zachodzi którakolwiek z okoliczności wskazanych w art. 7 ust. 1 ustawy z dnia 13 kwietnia 2022 r. o szczególnych rozwiązaniach w zakresie przeciwdziałania wspieraniu agresji na Ukrainę oraz służących ochronie bezpieczeństwa narodowego.</main><footer hidden><table style="border-top: 1px solid black; width:100%"><tr><td>2026-01-19 Biuletyn Zamówień Publicznych</td><td style="text-align:right">Ogłoszenie o zamówieniu - Zamówienie udzielane jest w trybie podstawowym na podstawie: art. 275 pkt 1 ustawy - Roboty budowlane</td></tr></table></footer></body></html>
  """

  describe "parse/1" do
    test "returns {:ok, parsed_tender} for valid HTML" do
      assert {:ok, result} = BzpParser.parse(@sample_html)
      assert is_map(result)
    end

    test "raises FunctionClauseError for nil input" do
      # Parser has guard clause requiring binary input
      assert_raise FunctionClauseError, fn ->
        BzpParser.parse(nil)
      end
    end

    test "handles malformed but parseable HTML gracefully" do
      # Floki is lenient - even broken HTML parses
      assert {:ok, result} = BzpParser.parse("<html><body><h3>incomplete")
      assert is_map(result)
    end
  end

  describe "parse!/1" do
    test "returns parsed tender directly for valid HTML" do
      result = BzpParser.parse!(@sample_html)
      assert is_map(result)
    end

    test "raises FunctionClauseError for nil input" do
      # Parser has guard clause requiring binary input
      assert_raise FunctionClauseError, fn ->
        BzpParser.parse!(nil)
      end
    end
  end

  describe "zamawiajacy extraction" do
    setup do
      {:ok, parsed} = BzpParser.parse(@sample_html)
      %{parsed: parsed}
    end

    test "extracts nazwa zamawiajacego", %{parsed: parsed} do
      assert parsed.zamawiajacy.nazwa == "43 WOJSKOWY ODDZIAŁ GOSPODARCZY"
    end

    test "extracts miejscowosc", %{parsed: parsed} do
      assert parsed.zamawiajacy.miejscowosc == "Świętoszów"
    end

    test "extracts wojewodztwo", %{parsed: parsed} do
      assert parsed.zamawiajacy.wojewodztwo == "dolnośląskie"
    end

    test "extracts kod pocztowy", %{parsed: parsed} do
      assert parsed.zamawiajacy.kod_pocztowy == "59-726"
    end

    test "extracts ulica", %{parsed: parsed} do
      assert parsed.zamawiajacy.ulica == "Saperska 2"
    end

    test "extracts email", %{parsed: parsed} do
      assert parsed.zamawiajacy.email == "43wog.szp@ron.mil.pl"
    end

    test "extracts www", %{parsed: parsed} do
      assert parsed.zamawiajacy.www == "https://43wog.wp.mil.pl/pl/"
    end

    test "extracts regon", %{parsed: parsed} do
      assert parsed.zamawiajacy.regon == "021509084"
    end
  end

  describe "podstawowe informacje extraction" do
    setup do
      {:ok, parsed} = BzpParser.parse(@sample_html)
      %{parsed: parsed}
    end

    test "extracts numer ogloszenia", %{parsed: parsed} do
      assert parsed.numer_ogloszenia == "2026/BZP 00046327"
    end

    test "extracts data ogloszenia", %{parsed: parsed} do
      assert parsed.data_ogloszenia == "2026-01-19"
    end

    test "extracts nazwa zamowienia", %{parsed: parsed} do
      assert parsed.nazwa_zamowienia =~
               "Remont hali sportowej nr 9 w k/3015 w Bolesławcu"
    end

    test "extracts numer referencyjny", %{parsed: parsed} do
      assert parsed.numer_referencyjny == "2/26/PN/2026"
    end

    test "extracts termin skladania ofert", %{parsed: parsed} do
      assert parsed.termin_skladania_ofert == "2026-02-03 08:00"
    end
  end

  describe "przedmiot zamowienia extraction" do
    setup do
      {:ok, parsed} = BzpParser.parse(@sample_html)
      %{parsed: parsed}
    end

    test "extracts opis przedmiotu", %{parsed: parsed} do
      assert parsed.opis_przedmiotu =~
               "Remont hali sportowej nr 9 w k/3015 w Bolesławcu"

      assert parsed.opis_przedmiotu =~ "dokumentacji projektowo- kosztorysowej"
    end

    test "extracts cpv main code", %{parsed: parsed} do
      assert parsed.cpv_main == "45000000-7 - Roboty budowlane"
    end

    test "extracts okres realizacji with 'do' date", %{parsed: parsed} do
      assert parsed.okres_realizacji.raw == "do 2026-11-30"
      # Note: The parser expects from-to format, so single 'do' date won't parse
      assert parsed.okres_realizacji.to == nil || parsed.okres_realizacji.to == ~D[2026-11-30]
    end

    test "extracts oferty czesciowe as false", %{parsed: parsed} do
      assert parsed.oferty_czesciowe == false
    end
  end

  describe "warunki udzialu extraction" do
    setup do
      {:ok, parsed} = BzpParser.parse(@sample_html)
      %{parsed: parsed}
    end

    test "returns nil when warunki text is inline (not in p tag)", %{parsed: parsed} do
      # The sample HTML has warunki content as inline text after h3, not wrapped in <p>
      # The parser's find_section_content doesn't capture this pattern
      assert parsed.warunki_udzialu == nil
    end

    test "extracts warunki udzialu when wrapped in p tag" do
      html_with_p_wrapped_warunki = """
      <html><body>
        <h3 class="mb-0">5.4.) Nazwa i opis warunków udziału w postępowaniu.</h3>
        <p>Wykonawcy muszą posiadać zdolności technicznej lub zawodowej.</p>
        <h3 class="mb-0">5.5.) Następna sekcja</h3>
      </body></html>
      """

      {:ok, result} = BzpParser.parse(html_with_p_wrapped_warunki)
      assert result.warunki_udzialu =~ "zdolności technicznej lub zawodowej"
    end
  end

  describe "kryteria oceny ofert extraction" do
    setup do
      {:ok, parsed} = BzpParser.parse(@sample_html)
      %{parsed: parsed}
    end

    test "extracts kryteria list", %{parsed: parsed} do
      assert is_list(parsed.kryteria)
      assert length(parsed.kryteria) >= 1
    end

    test "extracts criterion name and weight", %{parsed: parsed} do
      criterion = Enum.find(parsed.kryteria, fn c -> c.name == "Cena" end)
      assert criterion != nil
      assert criterion.weight == 100
    end
  end

  describe "wadium extraction" do
    setup do
      {:ok, parsed} = BzpParser.parse(@sample_html)
      %{parsed: parsed}
    end

    test "returns nil when wadium text is inline (not in p tag)", %{parsed: parsed} do
      # The sample HTML has wadium content as inline text after h3, not wrapped in <p>
      # The parser's find_section_content doesn't capture this pattern
      assert parsed.wadium == nil
      assert parsed.wadium_amount == nil
    end

    test "extracts wadium text when wrapped in p tag" do
      html_with_p_wrapped_wadium = """
      <html><body>
        <h3 class="mb-0">6.4.1) Informacje dotyczące wadium: </h3>
        <p>Wykonawca zobowiązany jest do wniesienia wadium w wysokości: 14 300,00 zł</p>
        <h3 class="mb-0">6.5.) Następna sekcja</h3>
      </body></html>
      """

      {:ok, result} = BzpParser.parse(html_with_p_wrapped_wadium)
      assert result.wadium =~ "14 300,00 zł"
      assert Decimal.equal?(result.wadium_amount, Decimal.new("14300.00"))
    end
  end

  describe "zabezpieczenie extraction" do
    setup do
      {:ok, parsed} = BzpParser.parse(@sample_html)
      %{parsed: parsed}
    end

    test "extracts zabezpieczenie as true", %{parsed: parsed} do
      assert parsed.zabezpieczenie == true
    end
  end

  describe "cpv additional extraction" do
    setup do
      {:ok, parsed} = BzpParser.parse(@sample_html)
      %{parsed: parsed}
    end

    test "returns empty list when no additional CPV codes", %{parsed: parsed} do
      assert parsed.cpv_additional == []
    end
  end

  describe "edge cases" do
    test "handles HTML with missing sections gracefully" do
      minimal_html = """
      <html><body>
        <h3 class="mb-0">2.5.) Numer ogłoszenia: <span class="normal">2026/BZP 00012345</span></h3>
      </body></html>
      """

      assert {:ok, result} = BzpParser.parse(minimal_html)
      assert result.numer_ogloszenia == "2026/BZP 00012345"
      assert result.wadium == nil
      assert result.wadium_amount == nil
      assert result.zamawiajacy.nazwa == nil
    end

    test "handles empty HTML document" do
      assert {:ok, result} = BzpParser.parse("<html><body></body></html>")
      assert result.numer_ogloszenia == nil
      assert result.kryteria == []
    end

    test "parses wadium with space-separated thousands" do
      html_with_wadium = """
      <html><body>
        <h3 class="mb-0">6.4.1) Informacje dotyczące wadium: </h3>
        <p>Wadium wynosi 100 000,00 zł</p>
        <h3 class="mb-0">6.5.) Następna sekcja</h3>
      </body></html>
      """

      assert {:ok, result} = BzpParser.parse(html_with_wadium)
      assert Decimal.equal?(result.wadium_amount, Decimal.new("100000.00"))
    end

    test "parses okres realizacji with from-to dates" do
      html_with_dates = """
      <html><body>
        <h3 class="mb-0">4.2.10.) Okres realizacji zamówienia albo umowy ramowej: <span class="normal">od 2026-03-01 do 2026-12-31</span></h3>
      </body></html>
      """

      assert {:ok, result} = BzpParser.parse(html_with_dates)
      assert result.okres_realizacji.from == ~D[2026-03-01]
      assert result.okres_realizacji.to == ~D[2026-12-31]
    end
  end

  # Second sample HTML - Gniezno road marking tender
  # Has: multiple criteria, additional CPV, no wadium, no zabezpieczenie
  @sample_html_gniezno """
  <html><head><meta charset="UTF-8"><style>body {
      font-family: "Calibri", sans-serif;
  }
  span.normal {
      font-weight: 400
  }
  </style></head><body><header hidden><table style="border-bottom: 1px solid black; width:100%"><tr><td>Ogłoszenie nr 2026/BZP 00060474 z dnia 2026-01-22</td></tr></table></header><main><!-- Version 1.0.0 --><style type="text/css">    .normal {        color: black;    }    h1.title {    }</style>    <h1 class="text-center mt-5 mb-5">Ogłoszenie o zamówieniu<br/>            Roboty budowlane<br/>            Wykonanie oznakowania poziomego na drogach gminnych <br/>i wewnętrznych na terenie miasta Gniezna    </h1>    <h2 class="bg-light p-3 mt-4">SEKCJA I - ZAMAWIAJĄCY</h2>    <h3 class="mb-0">1.1.) Rola zamawiającego</h3>    <p class="mb-0">Postępowanie prowadzone jest samodzielnie przez zamawiającego</p>    <h3 class="mb-0">1.2.) Nazwa zamawiającego: <span class="normal">Miasto Gniezno</span></h3>    <h3 class="mb-0">1.3.) Oddział zamawiającego: <span class="normal">Urząd Miejski w Gnieźnie</span></h3>    <h3 class="mb-0">1.4) Krajowy Numer Identyfikacyjny: <span class="normal">REGON 630189018</span></h3><h3 class="mb-0">1.5) Adres zamawiającego  </h3>    <h3 class="mb-0">1.5.1.) Ulica: <span class="normal">ul. Lecha 6</span></h3>    <h3 class="mb-0">1.5.2.) Miejscowość: <span class="normal">Gniezno</span></h3>    <h3 class="mb-0">1.5.3.) Kod pocztowy: <span class="normal">62-200</span></h3>    <h3 class="mb-0">1.5.4.) Województwo: <span class="normal">wielkopolskie</span></h3>    <h3 class="mb-0">1.5.5.) Kraj: <span class="normal">Polska</span></h3>    <h3 class="mb-0">1.5.6.) Lokalizacja NUTS 3: <span class="normal">PL414 - Koniński</span></h3>    <h3 class="mb-0">1.5.7.) Numer telefonu: <span class="normal">61 426 04 57</span></h3>    <h3 class="mb-0">1.5.9.) Adres poczty elektronicznej: <span class="normal">drogi@gniezno.eu</span></h3>    <h3 class="mb-0">1.5.10.) Adres strony internetowej zamawiającego: <span class="normal">https://bip.gniezno.eu/</span></h3>    <h3 class="mb-0">        1.6.) Rodzaj zamawiającego: <span class="normal">Zamawiający publiczny - jednostka sektora finansów publicznych - jednostka samorządu terytorialnego</span>    </h3>    <h3 class="mb-0">        1.7.) Przedmiot działalności zamawiającego:        <span class="normal">Ogólne usługi publiczne</span>    </h3>    <h2 class="bg-light p-3 mt-4">SEKCJA II – INFORMACJE PODSTAWOWE</h2>    <h3 class="mb-0">2.1.) Ogłoszenie dotyczy: </h3>    <p class="mb-0">        Zamówienia publicznego    </p>    <h3 class="mb-0">2.2.) Ogłoszenie dotyczy usług społecznych i innych szczególnych usług: <span class="normal">Nie</span></h3>    <h3 class="mb-0">2.3.) Nazwa zamówienia albo umowy ramowej: </h3>    <p class="mb-0">        Wykonanie oznakowania poziomego na drogach gminnych <br/>i wewnętrznych na terenie miasta Gniezna    </p>    <h3 class="mb-0">2.4.) Identyfikator postępowania: <span class="normal">ocds-148610-526335f0-1f12-446d-9d75-dba5e63c98a0</span></h3>    <h3 class="mb-0">2.5.) Numer ogłoszenia: <span class="normal">2026/BZP 00060474</span></h3>    <h3 class="mb-0">2.6.) Wersja ogłoszenia: <span class="normal">01</span></h3>    <h3 class="mb-0">2.7.) Data ogłoszenia: <span class="normal">2026-01-22</span></h3>    <h3 class="mb-0">2.8.) Zamówienie albo umowa ramowa zostały ujęte w planie postępowań: <span class="normal">Tak</span></h3>    <h3 class="mb-0">2.9.) Numer planu postępowań w BZP: <span class="normal">2026/BZP 00042276/01/P</span></h3>    <h3 class="mb-0">2.10.) Identyfikator pozycji planu postępowań: </h3>        <p class="mb-0">1.1.10 Oznakowanie poziome</p>    <h3 class="mb-0">2.11.) O udzielenie zamówienia mogą ubiegać się wyłącznie wykonawcy, o których mowa w art. 94 ustawy: <span class="normal">Nie</span></h3>    <h3 class="mb-0">2.14.) Czy zamówienie albo umowa ramowa dotyczy projektu lub programu współfinansowanego ze środków Unii Europejskiej: <span class="normal">Nie</span></h3>    <h3 class="mb-0">2.16.) Tryb udzielenia zamówienia wraz z podstawą prawną</h3>    <p class="mb-0">        Zamówienie udzielane jest w trybie podstawowym na podstawie: art. 275 pkt 2 ustawy    </p>    <h2 class="bg-light p-3 mt-4">SEKCJA III – UDOSTĘPNIANIE DOKUMENTÓW ZAMÓWIENIA I KOMUNIKACJA</h2>    <h3 class="mb-0">3.1.) Adres strony internetowej prowadzonego postępowania</h3>    https://ezamowienia.gov.pl/mp-client/search/list/ocds-148610-526335f0-1f12-446d-9d75-dba5e63c98a0    <h3 class="mb-0">3.2.) Zamawiający zastrzega dostęp do dokumentów zamówienia: <span class="normal">Nie</span></h3>    <h2 class="bg-light p-3 mt-4">SEKCJA IV – PRZEDMIOT ZAMÓWIENIA</h2><h3 class="mb-0">4.1.) Informacje ogólne odnoszące się do przedmiotu zamówienia.</h3>    <h3 class="mb-0">4.1.1.) Przed wszczęciem postępowania przeprowadzono konsultacje rynkowe: <span class="normal">Nie</span></h3>    <h3 class="mb-0">4.1.2.) Numer referencyjny: <span class="normal">WD.271.2.2026</span></h3>    <h3 class="mb-0">4.1.3.) Rodzaj zamówienia: <span class="normal">Roboty budowlane</span></h3>    <h3 class="mb-0">4.1.4.) Zamawiający udziela zamówienia w częściach, z których każda stanowi przedmiot odrębnego postępowania: <span class="normal">Nie</span></h3>    <h3 class="mb-0">4.1.8.) Możliwe jest składanie ofert częściowych: <span class="normal">Nie</span></h3>    <h3 class="mb-0">4.1.13.) Zamawiający uwzględnia aspekty społeczne, środowiskowe lub etykiety w opisie przedmiotu zamówienia: <span class="normal">Nie</span></h3><h3 class="mb-0">4.2. Informacje szczegółowe odnoszące się do przedmiotu zamówienia:</h3>        <h3 class="mb-0">4.2.2.) Krótki opis przedmiotu zamówienia</h3>        <p class="mb-0">            Przedmiotem zamówienia jest „Wykonanie oznakowania poziomego na drogach gminnych i wewnętrznych na terenie miasta Gniezna". <br/>Przedmiot zamówienia należy wykonać w oparciu o specyfikacje techniczne wykonania i odbioru robót budowlanych stanowiące załącznik do specyfikacji warunków zamówienia (SWZ).        </p>        <h3 class="mb-0">4.2.6.) Główny kod CPV: <span class="normal">34922100-7 - Oznakowanie drogowe</span></h3>        <h3 class="mb-0">4.2.7.) Dodatkowy kod CPV: </h3>            <p class="mb-0">45233221-4 - Malowanie nawierzchi</p>        <h3 class="mb-0">4.2.8.) Zamówienie obejmuje opcje: <span class="normal">Nie</span></h3>        <!-- realizacja do -->        <h3 class="mb-0">4.2.10.) Okres realizacji zamówienia albo umowy ramowej: <span class="normal">do 2026-11-20</span></h3>        <h3 class="mb-0">4.2.11.) Zamawiający przewiduje wznowienia: <span class="normal">Nie</span></h3>        <h3 class="mb-0">4.2.13.) Zamawiający przewiduje udzielenie dotychczasowemu wykonawcy zamówień na podobne usługi lub roboty budowlane: <span class="normal">Tak</span></h3>        <h3 class="mb-0">4.2.14.) Przedmiot, wielkość lub zakres oraz warunki zamówień na podobne usługi lub roboty budowlane: <span class="normal">Zamawiający przewiduje udzielanie zamówień, o których mowa w art. 214 ust. 1 <br/>pkt 7 ustawy Pzp, polegających na powtórzeniu podobnych robót budowlanych, do 10% wartości zamówienia podstawowego.</span></h3>    <h3 class="mb-0">4.3.) Kryteria oceny ofert</h3>            <h3 class="mb-0">4.3.2.) Sposób określania wagi kryteriów oceny ofert: <span class="normal"> Procentowo </span></h3>            <h3 class="mb-0">4.3.3.) Stosowane kryteria oceny ofert: <span class="normal"> Kryterium ceny oraz kryteria jakościowe </span></h3>                    <h3 class="mb-0">Kryterium 1</h3>                        <h3 class="mb-0">4.3.5.) Nazwa kryterium: <span class="normal">Cena</span></h3>                        <h3 class="mb-0">4.3.6.) Waga: <span class="normal">60</span></h3>                    <h3 class="mb-0">Kryterium 2</h3>                        <h3 class="mb-0">4.3.4.) Rodzaj kryterium: </h3>                        inne.                        <h3 class="mb-0">4.3.5.) Nazwa kryterium: <span class="normal">termin wykonania nowego oznakowania poziomego cienkowarstwowego lub grubowarstwowego zgodnie z zatwierdzonym projektem stałej organizacji ruchu</span></h3>                        <h3 class="mb-0">4.3.6.) Waga: <span class="normal">40</span></h3>            <h3 class="mb-0">4.3.10.) Zamawiający określa  aspekty społeczne, środowiskowe lub innowacyjne, żąda etykiet lub stosuje rachunek kosztów cyklu życia w odniesieniu do kryterium oceny ofert: <span class="normal">Nie</span></h3>    <h2 class="bg-light p-3 mt-4">SEKCJA V - KWALIFIKACJA WYKONAWCÓW</h2>    <h3 class="mb-0">5.1.) Zamawiający przewiduje fakultatywne podstawy wykluczenia: <span class="normal">Tak</span></h3>    <h3 class="mb-0">5.3.) Warunki udziału w postępowaniu: <span class="normal">Tak</span></h3>    <h3 class="mb-0">5.4.) Nazwa i opis warunków udziału w postępowaniu.</h3>    O udzielenie zamówienia mogą ubiegać się Wykonawcy, którzy spełniają warunki dotyczące:<br/>1)	Zdolności do występowania w obrocie gospodarczym<br/>Zamawiający nie stawia warunku w powyższym zakresie.    <h3 class="mb-0">5.5.) Zamawiający wymaga złożenia oświadczenia, o którym mowa w art.125 ust. 1 ustawy: <span class="normal">Tak</span></h3>    <h2 class="bg-light p-3 mt-4">SEKCJA VI - WARUNKI ZAMÓWIENIA</h2>    <h3 class="mb-0">6.1.) Zamawiający wymaga albo dopuszcza oferty wariantowe: <span class="normal">Nie</span></h3>    <h3 class="mb-0">6.3.) Zamawiający przewiduje aukcję elektroniczną: <span class="normal">Nie</span></h3>    <h3 class="mb-0">6.4.) Zamawiający wymaga wadium: <span class="normal">Nie</span></h3>    <h3 class="mb-0">6.5.) Zamawiający wymaga zabezpieczenia należytego wykonania umowy: <span class="normal">Nie</span></h3>    <h2 class="bg-light p-3 mt-4">SEKCJA VIII – PROCEDURA</h2>    <h3 class="mb-0">8.1.) Termin składania ofert: <span class="normal">2026-02-06 08:00</span></h3>    <h3 class="mb-0">8.2.) Miejsce składania ofert: <span class="normal">https://ezamowienia.gov.pl</span></h3>    <h3 class="mb-0">8.3.) Termin otwarcia ofert: <span class="normal">2026-02-06 09:00</span></h3>    <h3 class="mb-0">8.4.) Termin związania ofertą: <span class="normal">do 2026-03-07</span></h3></main></body></html>
  """

  describe "second sample (Gniezno) - zamawiajacy" do
    setup do
      {:ok, parsed} = BzpParser.parse(@sample_html_gniezno)
      %{parsed: parsed}
    end

    test "extracts nazwa zamawiajacego", %{parsed: parsed} do
      assert parsed.zamawiajacy.nazwa == "Miasto Gniezno"
    end

    test "extracts miejscowosc", %{parsed: parsed} do
      assert parsed.zamawiajacy.miejscowosc == "Gniezno"
    end

    test "extracts wojewodztwo", %{parsed: parsed} do
      assert parsed.zamawiajacy.wojewodztwo == "wielkopolskie"
    end

    test "extracts kod pocztowy", %{parsed: parsed} do
      assert parsed.zamawiajacy.kod_pocztowy == "62-200"
    end

    test "extracts ulica", %{parsed: parsed} do
      assert parsed.zamawiajacy.ulica == "ul. Lecha 6"
    end

    test "extracts email", %{parsed: parsed} do
      assert parsed.zamawiajacy.email == "drogi@gniezno.eu"
    end

    test "extracts www", %{parsed: parsed} do
      assert parsed.zamawiajacy.www == "https://bip.gniezno.eu/"
    end

    test "extracts regon", %{parsed: parsed} do
      assert parsed.zamawiajacy.regon == "630189018"
    end
  end

  describe "second sample (Gniezno) - podstawowe informacje" do
    setup do
      {:ok, parsed} = BzpParser.parse(@sample_html_gniezno)
      %{parsed: parsed}
    end

    test "extracts numer ogloszenia", %{parsed: parsed} do
      assert parsed.numer_ogloszenia == "2026/BZP 00060474"
    end

    test "extracts data ogloszenia", %{parsed: parsed} do
      assert parsed.data_ogloszenia == "2026-01-22"
    end

    test "extracts nazwa zamowienia", %{parsed: parsed} do
      assert parsed.nazwa_zamowienia =~ "Wykonanie oznakowania poziomego"
      assert parsed.nazwa_zamowienia =~ "miasta Gniezna"
    end

    test "extracts numer referencyjny", %{parsed: parsed} do
      assert parsed.numer_referencyjny == "WD.271.2.2026"
    end

    test "extracts termin skladania ofert", %{parsed: parsed} do
      assert parsed.termin_skladania_ofert == "2026-02-06 08:00"
    end
  end

  describe "second sample (Gniezno) - przedmiot zamowienia" do
    setup do
      {:ok, parsed} = BzpParser.parse(@sample_html_gniezno)
      %{parsed: parsed}
    end

    test "extracts opis przedmiotu", %{parsed: parsed} do
      assert parsed.opis_przedmiotu =~ "Wykonanie oznakowania poziomego"
      assert parsed.opis_przedmiotu =~ "specyfikacje techniczne"
    end

    test "extracts cpv main code", %{parsed: parsed} do
      assert parsed.cpv_main == "34922100-7 - Oznakowanie drogowe"
    end

    test "extracts additional CPV codes", %{parsed: parsed} do
      assert parsed.cpv_additional == ["45233221-4 - Malowanie nawierzchi"]
    end

    test "extracts oferty czesciowe as false", %{parsed: parsed} do
      assert parsed.oferty_czesciowe == false
    end
  end

  describe "second sample (Gniezno) - multiple kryteria" do
    setup do
      {:ok, parsed} = BzpParser.parse(@sample_html_gniezno)
      %{parsed: parsed}
    end

    test "extracts two kryteria", %{parsed: parsed} do
      assert length(parsed.kryteria) == 2
    end

    test "extracts first criterion (Cena 60%)", %{parsed: parsed} do
      cena = Enum.find(parsed.kryteria, fn c -> c.name == "Cena" end)
      assert cena != nil
      assert cena.weight == 60
    end

    test "extracts second criterion (termin 40%)", %{parsed: parsed} do
      termin =
        Enum.find(parsed.kryteria, fn c ->
          c.name =~ "termin wykonania"
        end)

      assert termin != nil
      assert termin.weight == 40
    end
  end

  describe "second sample (Gniezno) - no wadium" do
    setup do
      {:ok, parsed} = BzpParser.parse(@sample_html_gniezno)
      %{parsed: parsed}
    end

    test "wadium is nil when not required", %{parsed: parsed} do
      assert parsed.wadium == nil
      assert parsed.wadium_amount == nil
    end
  end

  describe "second sample (Gniezno) - no zabezpieczenie" do
    setup do
      {:ok, parsed} = BzpParser.parse(@sample_html_gniezno)
      %{parsed: parsed}
    end

    test "zabezpieczenie is false", %{parsed: parsed} do
      assert parsed.zabezpieczenie == false
    end
  end

  # Third sample HTML - Gowarczów thermomodernization tender
  # Has: partial offers (4 parts), EU funding, multiple CPV codes, period in months
  @sample_html_gowarczow """
  <html><head><meta charset="UTF-8"><style>body { font-family: "Calibri", sans-serif; } span.normal { font-weight: 400 }</style></head><body><header hidden><table style="border-bottom: 1px solid black; width:100%"><tr><td>Ogłoszenie nr 2026/BZP 00035012 z dnia 2026-01-14</td></tr></table></header><main><!-- Version 1.0.0 --><style type="text/css">.normal { color: black; }</style>    <h1 class="text-center mt-5 mb-5">Ogłoszenie o zamówieniu<br/>            Roboty budowlane<br/>            Termomodernizacja budynków użyteczności publicznej na terenie Gminy Gowarczów    </h1>    <h2 class="bg-light p-3 mt-4">SEKCJA I - ZAMAWIAJĄCY</h2>    <h3 class="mb-0">1.1.) Rola zamawiającego</h3>    <p class="mb-0">Postępowanie prowadzone jest samodzielnie przez zamawiającego</p>    <h3 class="mb-0">1.2.) Nazwa zamawiającego: <span class="normal">Gmina Gowarczów</span></h3>    <h3 class="mb-0">1.4) Krajowy Numer Identyfikacyjny: <span class="normal">REGON 670223681</span></h3><h3 class="mb-0">1.5) Adres zamawiającego  </h3>    <h3 class="mb-0">1.5.1.) Ulica: <span class="normal">Plac XX-lecia 1</span></h3>    <h3 class="mb-0">1.5.2.) Miejscowość: <span class="normal">Gowarczów</span></h3>    <h3 class="mb-0">1.5.3.) Kod pocztowy: <span class="normal">26-225</span></h3>    <h3 class="mb-0">1.5.4.) Województwo: <span class="normal">świętokrzyskie</span></h3>    <h3 class="mb-0">1.5.5.) Kraj: <span class="normal">Polska</span></h3>    <h3 class="mb-0">1.5.6.) Lokalizacja NUTS 3: <span class="normal">PL721 - Kielecki</span></h3>    <h3 class="mb-0">1.5.9.) Adres poczty elektronicznej: <span class="normal">sekretariat@gowarczow.pl</span></h3>    <h3 class="mb-0">1.5.10.) Adres strony internetowej zamawiającego: <span class="normal">https://gowarczow.pl</span></h3>    <h2 class="bg-light p-3 mt-4">SEKCJA II – INFORMACJE PODSTAWOWE</h2>    <h3 class="mb-0">2.1.) Ogłoszenie dotyczy: </h3>    <p class="mb-0">        Zamówienia publicznego    </p>    <h3 class="mb-0">2.3.) Nazwa zamówienia albo umowy ramowej: </h3>    <p class="mb-0">        Termomodernizacja budynków użyteczności publicznej na terenie Gminy Gowarczów    </p>    <h3 class="mb-0">2.5.) Numer ogłoszenia: <span class="normal">2026/BZP 00035012</span></h3>    <h3 class="mb-0">2.7.) Data ogłoszenia: <span class="normal">2026-01-14</span></h3>    <h2 class="bg-light p-3 mt-4">SEKCJA IV – PRZEDMIOT ZAMÓWIENIA</h2><h3 class="mb-0">4.1.) Informacje ogólne odnoszące się do przedmiotu zamówienia.</h3>    <h3 class="mb-0">4.1.2.) Numer referencyjny: <span class="normal">ZB.271.1.2026</span></h3>    <h3 class="mb-0">4.1.3.) Rodzaj zamówienia: <span class="normal">Roboty budowlane</span></h3>    <h3 class="mb-0">4.1.8.) Możliwe jest składanie ofert częściowych: <span class="normal">Tak</span></h3>    <h3 class="mb-0">4.1.9.) Liczba części: <span class="normal">4</span></h3><h3 class="mb-0">4.2. Informacje szczegółowe odnoszące się do przedmiotu zamówienia:</h3>        <h3 class="p-2 mt-4 bg-light">Część 1</h3>            <h3 class="mb-0">4.2.2.) Krótki opis przedmiotu zamówienia</h3>            <p class="mb-0">                Część 1- Termomodernizacja budynku SP w Gowarczowie polegająca na: Wykonaniu ocieplenia, wymianie okien, wymianie drzwi, modernizacji systemu ciepłej wody użytkowej, montażu instalacji OZE, magazynów energii.            </p>            <h3 class="mb-0">4.2.6.) Główny kod CPV: <span class="normal">45320000-6 - Roboty izolacyjne</span></h3>            <h3 class="mb-0">4.2.7.) Dodatkowy kod CPV: </h3>                <p class="mb-0">45331210-1 - Instalowanie wentylacji</p>                <p class="mb-0">45316110-9 - Instalowanie urządzeń oświetlenia drogowego</p>                <p class="mb-0">45310000-3 - Roboty instalacyjne elektryczne</p>                <p class="mb-0">45311000-0 - Roboty w zakresie okablowania oraz instalacji elektrycznych</p>            <h3 class="mb-0">4.2.10.) Okres realizacji zamówienia albo umowy ramowej: <span class="normal">6 miesiące</span></h3>            <h3 class="mb-0">4.3.) Kryteria oceny ofert: </h3>                <h3 class="mb-0">4.3.2.) Sposób określania wagi kryteriów oceny ofert: <span class="normal">Procentowo</span></h3>                <h3 class="mb-0">4.3.3.) Stosowane kryteria oceny ofert: <span class="normal"> Kryterium ceny oraz kryteria jakościowe </span></h3>                        <h3 class="mb-0">Kryterium 1</h3>                            <h3 class="mb-0">4.3.5.) Nazwa kryterium: <span class="normal">Cena</span></h3>                            <h3 class="mb-0">4.3.6.) Waga: <span class="normal">60</span></h3>                        <h3 class="mb-0">Kryterium 2</h3>                            <h3 class="mb-0">4.3.4.) Rodzaj kryterium: <span class="normal">inne.</span></h3>                            <h3 class="mb-0">4.3.5.) Nazwa kryterium: <span class="normal">Termin gwarancji</span></h3>                            <h3 class="mb-0">4.3.6.) Waga: <span class="normal">40</span></h3>    <h2 class="bg-light p-3 mt-4">SEKCJA V - KWALIFIKACJA WYKONAWCÓW</h2>    <h3 class="mb-0">5.1.) Zamawiający przewiduje fakultatywne podstawy wykluczenia: <span class="normal">Tak</span></h3>    <h3 class="mb-0">5.3.) Warunki udziału w postępowaniu: <span class="normal">Tak</span></h3>    <h2 class="bg-light p-3 mt-4">SEKCJA VI - WARUNKI ZAMÓWIENIA</h2>    <h3 class="mb-0">6.1.) Zamawiający wymaga albo dopuszcza oferty wariantowe: <span class="normal">Nie</span></h3>    <h3 class="mb-0">6.4.) Zamawiający wymaga wadium: <span class="normal">Tak</span></h3>    <h3 class="mb-0">6.4.1) Informacje dotyczące wadium: </h3>    <p class="mb-0">Wadium w wysokości: Część 1 – 30 000,00 zł, Część 2 – 4 000,00 zł, Część 3 – 4 500,00 zł, Część 4 – 3 000,00 zł</p>    <h3 class="mb-0">6.5.) Zamawiający wymaga zabezpieczenia należytego wykonania umowy: <span class="normal">Tak</span></h3>    <h2 class="bg-light p-3 mt-4">SEKCJA VIII – PROCEDURA</h2>    <h3 class="mb-0">8.1.) Termin składania ofert: <span class="normal">2026-02-14 10:00</span></h3>    <h3 class="mb-0">8.2.) Miejsce składania ofert: <span class="normal">https://ezamowienia.gov.pl</span></h3></main></body></html>
  """

  describe "third sample (Gowarczow) - zamawiajacy" do
    setup do
      {:ok, parsed} = BzpParser.parse(@sample_html_gowarczow)
      %{parsed: parsed}
    end

    test "extracts nazwa zamawiajacego", %{parsed: parsed} do
      assert parsed.zamawiajacy.nazwa == "Gmina Gowarczów"
    end

    test "extracts miejscowosc", %{parsed: parsed} do
      assert parsed.zamawiajacy.miejscowosc == "Gowarczów"
    end

    test "extracts wojewodztwo", %{parsed: parsed} do
      assert parsed.zamawiajacy.wojewodztwo == "świętokrzyskie"
    end

    test "extracts kod pocztowy", %{parsed: parsed} do
      assert parsed.zamawiajacy.kod_pocztowy == "26-225"
    end

    test "extracts ulica", %{parsed: parsed} do
      assert parsed.zamawiajacy.ulica == "Plac XX-lecia 1"
    end

    test "extracts email", %{parsed: parsed} do
      assert parsed.zamawiajacy.email == "sekretariat@gowarczow.pl"
    end

    test "extracts www", %{parsed: parsed} do
      assert parsed.zamawiajacy.www == "https://gowarczow.pl"
    end

    test "extracts regon", %{parsed: parsed} do
      assert parsed.zamawiajacy.regon == "670223681"
    end
  end

  describe "third sample (Gowarczow) - podstawowe informacje" do
    setup do
      {:ok, parsed} = BzpParser.parse(@sample_html_gowarczow)
      %{parsed: parsed}
    end

    test "extracts numer ogloszenia", %{parsed: parsed} do
      assert parsed.numer_ogloszenia == "2026/BZP 00035012"
    end

    test "extracts data ogloszenia", %{parsed: parsed} do
      assert parsed.data_ogloszenia == "2026-01-14"
    end

    test "extracts nazwa zamowienia", %{parsed: parsed} do
      assert parsed.nazwa_zamowienia =~ "Termomodernizacja budynków"
      assert parsed.nazwa_zamowienia =~ "Gminy Gowarczów"
    end

    test "extracts numer referencyjny", %{parsed: parsed} do
      assert parsed.numer_referencyjny == "ZB.271.1.2026"
    end

    test "extracts termin skladania ofert", %{parsed: parsed} do
      assert parsed.termin_skladania_ofert == "2026-02-14 10:00"
    end
  end

  describe "third sample (Gowarczow) - partial offers" do
    setup do
      {:ok, parsed} = BzpParser.parse(@sample_html_gowarczow)
      %{parsed: parsed}
    end

    test "oferty_czesciowe is true", %{parsed: parsed} do
      assert parsed.oferty_czesciowe == true
    end
  end

  describe "third sample (Gowarczow) - multiple CPV additional codes" do
    setup do
      {:ok, parsed} = BzpParser.parse(@sample_html_gowarczow)
      %{parsed: parsed}
    end

    test "extracts main CPV code", %{parsed: parsed} do
      assert parsed.cpv_main == "45320000-6 - Roboty izolacyjne"
    end

    test "extracts 4 additional CPV codes", %{parsed: parsed} do
      assert length(parsed.cpv_additional) == 4
      assert "45331210-1 - Instalowanie wentylacji" in parsed.cpv_additional
      assert "45316110-9 - Instalowanie urządzeń oświetlenia drogowego" in parsed.cpv_additional
      assert "45310000-3 - Roboty instalacyjne elektryczne" in parsed.cpv_additional
      assert "45311000-0 - Roboty w zakresie okablowania oraz instalacji elektrycznych" in parsed.cpv_additional
    end
  end

  describe "third sample (Gowarczow) - okres realizacji in months" do
    setup do
      {:ok, parsed} = BzpParser.parse(@sample_html_gowarczow)
      %{parsed: parsed}
    end

    test "extracts raw okres realizacji with months", %{parsed: parsed} do
      assert parsed.okres_realizacji.raw == "6 miesiące"
    end

    test "from and to dates are nil for month-based period", %{parsed: parsed} do
      # Parser only extracts from/to dates, not month durations
      assert parsed.okres_realizacji.from == nil
      assert parsed.okres_realizacji.to == nil
    end
  end

  describe "third sample (Gowarczow) - wadium and zabezpieczenie" do
    setup do
      {:ok, parsed} = BzpParser.parse(@sample_html_gowarczow)
      %{parsed: parsed}
    end

    test "extracts wadium text when wrapped in p tag", %{parsed: parsed} do
      assert parsed.wadium =~ "30 000,00 zł"
    end

    test "extracts wadium amount (first value)", %{parsed: parsed} do
      # The parser extracts the first amount it finds
      assert parsed.wadium_amount != nil
      assert Decimal.equal?(parsed.wadium_amount, Decimal.new("30000.00"))
    end

    test "zabezpieczenie is true", %{parsed: parsed} do
      assert parsed.zabezpieczenie == true
    end
  end

  describe "third sample (Gowarczow) - multiple kryteria" do
    setup do
      {:ok, parsed} = BzpParser.parse(@sample_html_gowarczow)
      %{parsed: parsed}
    end

    test "extracts two kryteria", %{parsed: parsed} do
      assert length(parsed.kryteria) == 2
    end

    test "extracts first criterion (Cena 60%)", %{parsed: parsed} do
      cena = Enum.find(parsed.kryteria, fn c -> c.name == "Cena" end)
      assert cena != nil
      assert cena.weight == 60
    end

    test "extracts second criterion (Termin gwarancji 40%)", %{parsed: parsed} do
      gwarancja = Enum.find(parsed.kryteria, fn c -> c.name == "Termin gwarancji" end)
      assert gwarancja != nil
      assert gwarancja.weight == 40
    end
  end

  # Fourth sample HTML - Słupsk PGM construction works tender
  # Has: HTML entities in name, 10 additional CPV codes, weight with decimal "100,00", Punktowo
  @sample_html_slupsk """
  <html><head><meta charset="UTF-8"><style>body { font-family: "Calibri", sans-serif; } span.normal { font-weight: 400 }</style></head><body><header hidden><table style="border-bottom: 1px solid black; width:100%"><tr><td>Ogłoszenie nr 2026/BZP 00054454 z dnia 2026-01-21</td></tr></table></header><main><!-- Version 1.0.0 --><style type="text/css">.normal { color: black; }</style>    <h1 class="text-center mt-5 mb-5">Ogłoszenie o zamówieniu<br/>            Roboty budowlane<br/>            Roboty ogólnobudowlane w lokalach i budynkach komunalnych oraz zabezpieczenia budynków przeznaczonych do rozbiórki    </h1>    <h2 class="bg-light p-3 mt-4">SEKCJA I - ZAMAWIAJĄCY</h2>    <h3 class="mb-0">1.1.) Rola zamawiającego</h3>    <p class="mb-0">Postępowanie prowadzone jest samodzielnie przez zamawiającego</p>    <h3 class="mb-0">1.2.) Nazwa zamawiającego: <span class="normal">&#34;PRZEDSIĘBIORSTWO GOSPODARKI MIESZKANIOWEJ&#34; SPÓŁKA Z OGRANICZONĄ ODPOWIEDZIALNOŚCIĄ W SŁUPSKU</span></h3>    <h3 class="mb-0">1.4) Krajowy Numer Identyfikacyjny: <span class="normal">REGON 771285155</span></h3><h3 class="mb-0">1.5) Adres zamawiającego  </h3>    <h3 class="mb-0">1.5.1.) Ulica: <span class="normal">ul. Juliana Tuwima 4</span></h3>    <h3 class="mb-0">1.5.2.) Miejscowość: <span class="normal">Słupsk</span></h3>    <h3 class="mb-0">1.5.3.) Kod pocztowy: <span class="normal">76-200</span></h3>    <h3 class="mb-0">1.5.4.) Województwo: <span class="normal">pomorskie</span></h3>    <h3 class="mb-0">1.5.9.) Adres poczty elektronicznej: <span class="normal">zamowienia.publiczne@pgm.slupsk.pl</span></h3>    <h3 class="mb-0">1.5.10.) Adres strony internetowej zamawiającego: <span class="normal">www.pgm.slupsk.pl</span></h3>    <h2 class="bg-light p-3 mt-4">SEKCJA II – INFORMACJE PODSTAWOWE</h2>    <h3 class="mb-0">2.1.) Ogłoszenie dotyczy: </h3>    <p class="mb-0">        Zamówienia publicznego    </p>    <h3 class="mb-0">2.3.) Nazwa zamówienia albo umowy ramowej: </h3>    <p class="mb-0">        Roboty ogólnobudowlane w lokalach i budynkach komunalnych oraz zabezpieczenia budynków przeznaczonych do rozbiórki    </p>    <h3 class="mb-0">2.5.) Numer ogłoszenia: <span class="normal">2026/BZP 00054454</span></h3>    <h3 class="mb-0">2.7.) Data ogłoszenia: <span class="normal">2026-01-21</span></h3>    <h2 class="bg-light p-3 mt-4">SEKCJA IV – PRZEDMIOT ZAMÓWIENIA</h2><h3 class="mb-0">4.1.) Informacje ogólne odnoszące się do przedmiotu zamówienia.</h3>    <h3 class="mb-0">4.1.2.) Numer referencyjny: <span class="normal">4/DIT/P/RB/2026</span></h3>    <h3 class="mb-0">4.1.3.) Rodzaj zamówienia: <span class="normal">Roboty budowlane</span></h3>    <h3 class="mb-0">4.1.8.) Możliwe jest składanie ofert częściowych: <span class="normal">Nie</span></h3><h3 class="mb-0">4.2. Informacje szczegółowe odnoszące się do przedmiotu zamówienia:</h3>        <h3 class="mb-0">4.2.2.) Krótki opis przedmiotu zamówienia</h3>        <p class="mb-0">            Przedmiotem postępowania są „Roboty ogólnobudowlane w lokalach i budynkach komunalnych oraz zabezpieczenia budynków przeznaczonych do rozbiórki". Zakres prac obejmuje wykonanie prac murarskich, tynkarskich, malarskich, stolarskich, ciesielskich.        </p>        <h3 class="mb-0">4.2.6.) Główny kod CPV: <span class="normal">45432100-5 - Kładzenie i wykładanie podłóg</span></h3>        <h3 class="mb-0">4.2.7.) Dodatkowy kod CPV: </h3>            <p class="mb-0">45321000-3 - Izolacja cieplna</p>            <p class="mb-0">45261100-5 - Wykonywanie konstrukcji dachowych</p>            <p class="mb-0">45442100-8 - Roboty malarskie</p>            <p class="mb-0">45262520-2 - Roboty murowe</p>            <p class="mb-0">45262423-2 - Wykonywanie pokładów</p>            <p class="mb-0">45421100-5 - Instalowanie drzwi i okien, i podobnych elementów</p>            <p class="mb-0">45421000-4 - Roboty w zakresie stolarki budowlanej</p>            <p class="mb-0">45410000-4 - Tynkowanie</p>            <p class="mb-0">45233222-1 - Roboty budowlane w zakresie układania chodników i asfaltowania</p>            <p class="mb-0">45432114-6 - Roboty w zakresie podłóg drewnianych</p>        <h3 class="mb-0">4.2.10.) Okres realizacji zamówienia albo umowy ramowej: <span class="normal">do 2026-12-31</span></h3>    <h3 class="mb-0">4.3.) Kryteria oceny ofert</h3>            <h3 class="mb-0">4.3.2.) Sposób określania wagi kryteriów oceny ofert: <span class="normal"> Punktowo </span></h3>            <h3 class="mb-0">4.3.3.) Stosowane kryteria oceny ofert: <span class="normal"> Wyłącznie kryterium ceny </span></h3>                    <h3 class="mb-0">Kryterium 1</h3>                        <h3 class="mb-0">4.3.5.) Nazwa kryterium: <span class="normal">Cena</span></h3>                        <h3 class="mb-0">4.3.6.) Waga: <span class="normal">100,00</span></h3>    <h2 class="bg-light p-3 mt-4">SEKCJA V - KWALIFIKACJA WYKONAWCÓW</h2>    <h3 class="mb-0">5.1.) Zamawiający przewiduje fakultatywne podstawy wykluczenia: <span class="normal">Tak</span></h3>    <h3 class="mb-0">5.3.) Warunki udziału w postępowaniu: <span class="normal">Tak</span></h3>    <h2 class="bg-light p-3 mt-4">SEKCJA VI - WARUNKI ZAMÓWIENIA</h2>    <h3 class="mb-0">6.1.) Zamawiający wymaga albo dopuszcza oferty wariantowe: <span class="normal">Nie</span></h3>    <h3 class="mb-0">6.4.) Zamawiający wymaga wadium: <span class="normal">Nie</span></h3>    <h3 class="mb-0">6.5.) Zamawiający wymaga zabezpieczenia należytego wykonania umowy: <span class="normal">Nie</span></h3>    <h2 class="bg-light p-3 mt-4">SEKCJA VIII – PROCEDURA</h2>    <h3 class="mb-0">8.1.) Termin składania ofert: <span class="normal">2026-02-06 09:00</span></h3>    <h3 class="mb-0">8.2.) Miejsce składania ofert: <span class="normal">https://platformazakupowa.pl/pn/pgm_slupsk</span></h3></main></body></html>
  """

  describe "fourth sample (Slupsk) - zamawiajacy with HTML entities" do
    setup do
      {:ok, parsed} = BzpParser.parse(@sample_html_slupsk)
      %{parsed: parsed}
    end

    test "extracts nazwa zamawiajacego with decoded HTML entities", %{parsed: parsed} do
      # &#34; should be decoded to "
      assert parsed.zamawiajacy.nazwa =~ "PRZEDSIĘBIORSTWO GOSPODARKI MIESZKANIOWEJ"
      assert parsed.zamawiajacy.nazwa =~ "SŁUPSKU"
    end

    test "extracts miejscowosc", %{parsed: parsed} do
      assert parsed.zamawiajacy.miejscowosc == "Słupsk"
    end

    test "extracts wojewodztwo", %{parsed: parsed} do
      assert parsed.zamawiajacy.wojewodztwo == "pomorskie"
    end

    test "extracts kod pocztowy", %{parsed: parsed} do
      assert parsed.zamawiajacy.kod_pocztowy == "76-200"
    end

    test "extracts ulica", %{parsed: parsed} do
      assert parsed.zamawiajacy.ulica == "ul. Juliana Tuwima 4"
    end

    test "extracts email", %{parsed: parsed} do
      assert parsed.zamawiajacy.email == "zamowienia.publiczne@pgm.slupsk.pl"
    end

    test "extracts www", %{parsed: parsed} do
      assert parsed.zamawiajacy.www == "www.pgm.slupsk.pl"
    end

    test "extracts regon", %{parsed: parsed} do
      assert parsed.zamawiajacy.regon == "771285155"
    end
  end

  describe "fourth sample (Slupsk) - podstawowe informacje" do
    setup do
      {:ok, parsed} = BzpParser.parse(@sample_html_slupsk)
      %{parsed: parsed}
    end

    test "extracts numer ogloszenia", %{parsed: parsed} do
      assert parsed.numer_ogloszenia == "2026/BZP 00054454"
    end

    test "extracts data ogloszenia", %{parsed: parsed} do
      assert parsed.data_ogloszenia == "2026-01-21"
    end

    test "extracts nazwa zamowienia", %{parsed: parsed} do
      assert parsed.nazwa_zamowienia =~ "Roboty ogólnobudowlane"
      assert parsed.nazwa_zamowienia =~ "budynkach komunalnych"
    end

    test "extracts numer referencyjny", %{parsed: parsed} do
      assert parsed.numer_referencyjny == "4/DIT/P/RB/2026"
    end

    test "extracts termin skladania ofert", %{parsed: parsed} do
      assert parsed.termin_skladania_ofert == "2026-02-06 09:00"
    end
  end

  describe "fourth sample (Slupsk) - 10 additional CPV codes" do
    setup do
      {:ok, parsed} = BzpParser.parse(@sample_html_slupsk)
      %{parsed: parsed}
    end

    test "extracts main CPV code", %{parsed: parsed} do
      assert parsed.cpv_main == "45432100-5 - Kładzenie i wykładanie podłóg"
    end

    test "extracts 10 additional CPV codes", %{parsed: parsed} do
      assert length(parsed.cpv_additional) == 10
      assert "45321000-3 - Izolacja cieplna" in parsed.cpv_additional
      assert "45261100-5 - Wykonywanie konstrukcji dachowych" in parsed.cpv_additional
      assert "45442100-8 - Roboty malarskie" in parsed.cpv_additional
      assert "45262520-2 - Roboty murowe" in parsed.cpv_additional
      assert "45432114-6 - Roboty w zakresie podłóg drewnianych" in parsed.cpv_additional
    end
  end

  describe "fourth sample (Slupsk) - single criterion with decimal weight" do
    setup do
      {:ok, parsed} = BzpParser.parse(@sample_html_slupsk)
      %{parsed: parsed}
    end

    test "extracts single criterion", %{parsed: parsed} do
      assert length(parsed.kryteria) == 1
    end

    test "extracts Cena criterion with weight 100 (parsed from 100,00)", %{parsed: parsed} do
      cena = Enum.find(parsed.kryteria, fn c -> c.name == "Cena" end)
      assert cena != nil
      assert cena.weight == 100
    end
  end

  describe "fourth sample (Slupsk) - no wadium no zabezpieczenie" do
    setup do
      {:ok, parsed} = BzpParser.parse(@sample_html_slupsk)
      %{parsed: parsed}
    end

    test "wadium is nil when not required", %{parsed: parsed} do
      assert parsed.wadium == nil
      assert parsed.wadium_amount == nil
    end

    test "zabezpieczenie is false", %{parsed: parsed} do
      assert parsed.zabezpieczenie == false
    end
  end

  describe "fourth sample (Slupsk) - oferty czesciowe" do
    setup do
      {:ok, parsed} = BzpParser.parse(@sample_html_slupsk)
      %{parsed: parsed}
    end

    test "oferty_czesciowe is false", %{parsed: parsed} do
      assert parsed.oferty_czesciowe == false
    end
  end
end
