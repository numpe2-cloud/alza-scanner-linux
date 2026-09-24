# Alza Scanner (Linux / Docker verze)

![Testy](https://github.com/numpe2-cloud/alza-scanner-linux/actions/workflows/testy.yml/badge.svg)

> Toto je Linux verze projektu, která běží v Docker kontejneru a má CI/CD pipeline přes GitHub Actions.
> Původní Windows verze (spouštěná přes Windows Task Scheduler): [alza-scanner](https://github.com/numpe2-cloud/alza-scanner)

Osobní nástroj pro sledování cen vybraných produktů na Alza.cz. Hlídá historické minimum a pošle e-mailový alert, když cena klesne pod obvyklou hranici.

![Architektura Alza Scanneru](schema.png)

## Motivace

Chtěl jsem vytvořit něco, co pro mě bude užitečné v praxi. Nejdřív jsem uvažoval nad scraperem obsahu Českého rozhlasu, ale postupně mi došlo, že bych ho stejně nevyužíval. Sledování vývoje cen u produktů, který si časem plánuji koupit, mi přišlo jako mnohem praktičtější nápad. Do projektu si teď můžu přidat jakýkoliv produkt a sledovat jeho cenu, dokud se nerozhodnu koupit.

Vím, že podobná řešení už existují a možná i lepší než to moje, ale bavilo mě zkusit si to postavit od nuly. Překvapilo mě, jak i na první pohled malý projekt je ve skutečnosti komplexní a kolik různých problémů se během vývoje objeví. Například jsem musel vyzkoušet víc postupů, než se mi podařilo obejít zabezpečení stránek Alzy a spolehlivě načíst aktuální cenu.

## Tech stack

- **Python 3** — hlavní jazyk projektu
- **Playwright** — scraping cen z Alza.cz (headless=False kvůli obejití Cloudflare ochrany)
- **PyYAML** — konfigurace sledovaných produktů (`polozky.yaml`)
- **csv** / **datetime** — ukládání a práce s historií cen
- **smtplib** — odesílání e-mailových alertů
- **python-dotenv** — správa citlivých údajů (přihlašovací údaje k e-mailu) mimo kód
- **matplotlib** — grafy vývoje cen v dashboardu
- **pytest** — automatizované testy
- **flake8** — kontrola stylu kódu
- **Docker / Docker Compose** — běh celého projektu v kontejneru
- **Xvfb** — virtuální displej v kontejneru, aby prohlížeč s `headless=False` běžel i na serveru bez monitoru
- **GitHub Actions** — CI/CD pipeline (testy + sestavení image při každém pushi)

## Jak to funguje

Projekt má tři hlavní části:

1. **Sběr a ukládání cen** — `scraper.py` načte aktuální ceny sledovaných produktů (definovaných v `polozky.yaml`), `ulozeni_ceny.py` je uloží do `monitoringcen.csv`
2. **Kontrola a alerty** — `kontrola_ceny.py` porovná aktuální cenu s historickým minimem za posledních 6 měsíců (`historie_cen.py`, `posouzeni_ceny.py`) a při výhodné ceně pošle e-mailový alert (`alerty.py`, `odeslani_emailu.py`), s deduplikací přes 30denní cooldown
3. **Dashboard** — `vytvor_report.py` sestaví HTML přehled s grafy vývoje cen (`report_data.py`, `grafy_cen.py`, `report_html.py`)

Podrobné schéma toků mezi jednotlivými soubory je výše.

### Spouštění

| Vstupní bod | Jak se spouští |
|---|---|
| `kontrola_ceny.py` | výchozí příkaz kontejneru: `docker compose up --build` |
| `ulozeni_ceny.py` | ručně, přepsáním výchozího příkazu přes `docker compose run` (viz Spuštění v Dockeru, krok 5) |
| `vytvor_report.py` | jen bez Dockeru: `python vytvor_report.py` (v kontejneru by `report.html` zmizel) |

### Struktura projektu

```
alza-scanner-linux/
├── kontrola_ceny.py        # VSTUPNÍ BOD – porovná ceny s minimem, pošle alert
├── ulozeni_ceny.py         # VSTUPNÍ BOD – uloží aktuální ceny do historie
├── vytvor_report.py        # VSTUPNÍ BOD – vytvoří HTML dashboard s grafy
├── config/
│   └── polozky.yaml        # seznam sledovaných produktů (jediné místo, kde se mění)
├── src/
│   ├── scraper.py          # načte aktuální ceny z Alza.cz (Playwright)
│   ├── nacti_polozky.py    # načte produkty z polozky.yaml
│   ├── uloz_cenu.py        # připíše cenu do monitoringcen.csv
│   ├── historie_cen.py     # najde historické minimum za posledních 182 dní
│   ├── posouzeni_ceny.py   # rozhodne, jestli je cena výrazně pod minimem
│   ├── alerty.py           # hlídá 30denní pauzu mezi alerty na stejný produkt
│   ├── odeslani_emailu.py  # odešle e-mail přes Gmail (smtplib)
│   ├── report_data.py      # připraví data pro dashboard
│   ├── grafy_cen.py        # vykreslí grafy vývoje cen (matplotlib)
│   └── report_html.py      # sestaví HTML stránku dashboardu
├── test/
│   ├── test_posouzeni_ceny.py
│   └── test_najdi_minimum.py
├── .github/workflows/
│   └── testy.yml           # CI/CD: testy + flake8 + sestavení Docker image
├── Dockerfile              # image s Pythonem, Playwrightem a Xvfb
├── docker-compose.yaml     # spuštění kontejneru s .env a složkou data/
├── requirements.txt        # Python knihovny
├── conftest.py             # prázdný, aby pytest našel moduly v src/
├── .flake8                 # pravidla kontroly stylu
├── .gitignore
└── schema.png              # diagram toku dat
```

## Předpoklady

- Linux nebo WSL
- Docker a Docker Compose (na Ubuntu balíčky `docker.io` a `docker-compose-v2`)
- Pro spuštění bez Dockeru: Python 3.14

## Spuštění v Dockeru

1. Naklonuj repozitář:
   ```
   git clone https://github.com/numpe2-cloud/alza-scanner-linux
   cd alza-scanner-linux
   ```

2. Vytvoř soubor `.env` v kořeni projektu (viz sekce Proměnné prostředí níže).

3. Nastav sledované produkty v `config/polozky.yaml` podle existujícího vzoru.

4. Sestav image a spusť kontrolu cen:
   ```
   docker compose up --build
   ```
   Výchozí příkaz kontejneru je `kontrola_ceny.py`. Přepínač `--build` znovu sestaví image - je potřeba po každé změně kódu nebo `polozky.yaml`, protože se soubory kopírují do image při sestavení.

5. Uložení aktuálních cen do historie (jiný příkaz než výchozí):
   ```
   docker compose run --rm kontrola sh -c "Xvfb :99 -screen 0 1280x1024x24 -ac -nolisten tcp & sleep 2 && DISPLAY=:99 python ulozeni_ceny.py"
   ```
   Virtuální displej se musí spustit i tady, protože vlastní příkaz nahradí celý výchozí `CMD` z `Dockerfile`.

Historie cen se ukládá do složky `data/` na hostiteli (volume `./data:/app/data`), takže zůstane zachovaná i po smazání kontejneru.

Kontejner provede jednu kontrolu a skončí. Pro pravidelné spouštění lze příkazy výše naplánovat přes cron na hostiteli.

Dashboard (`report.html`) se v Docker verzi negeneruje. Soubor by se uložil mimo volume a zmizel by spolu s kontejnerem. Je možné ho vytvořit lokálně příkazem `python vytvor_report.py` (viz sekce Spuštění bez Dockeru).

## Spuštění bez Dockeru

1. Vytvoř a aktivuj virtuální prostředí:
   ```
   python -m venv .venv
   source .venv/bin/activate
   ```

2. Nainstaluj závislosti:
   ```
   pip install -r requirements.txt
   playwright install
   ```

3. Spusť ruční test:
   ```
   python ulozeni_ceny.py
   ```
   Zkontroluj, že se cena uložila do `data/monitoringcen.csv`, a pak:
   ```
   python kontrola_ceny.py
   ```

4. Vytvoř dashboard s grafy vývoje cen:
   ```
   python vytvor_report.py
   ```
   V kořeni projektu vznikne `report.html`, který otevřeš v prohlížeči.

## Proměnné prostředí

Projekt potřebuje soubor `.env` v kořeni projektu (nikdy se necommituje do gitu. Je v `.gitignore`) s těmito proměnnými:

```
odesilatel=tvuj_email@gmail.com
heslo=tvoje_app_password
prijemce=email_kam_chodi_alerty@example.com
```

**Poznámka:** `heslo` musí být Gmail App Password (vygenerovaný v nastavení Google účtu), ne běžné heslo k účtu. Gmail SMTP s normálním heslem odmítne přihlášení.

V Dockeru se `.env` předává kontejneru přes `env_file` v `docker-compose.yaml`.

## Testování

Projekt má jednotkové testy (`pytest`) pro čisté funkce (`posouzeni_ceny()`, `najdi_minimum()`) a je průběžně kontrolovaný linterem `flake8`.

```
pytest
flake8 .
```

## CI/CD

Při každém pushi do větve `master` proběhne GitHub Actions pipeline (`.github/workflows/testy.yml`):

1. **testy** — nainstaluje závislosti, spustí `pytest` a `flake8 src/`
2. **build** — sestaví Docker image; spustí se jen tehdy, když testy projdou (`needs: testy`)

Image se záměrně nenahrává na Docker Hub. Docker verze slouží jako ukázka kontejnerizace, v běžném provozu projekt běží na Windows přes Task Scheduler.

## Proč takhle

- **CSV místo databáze** — CSV jsem znal a na pár produktů s několika záznamy týdně úplně stačí. Soubor se dá otevřít v čemkoliv a nic dalšího se nemusí instalovat. Při velkém objemu dat by bylo CSV pomalé, tady to ale nehrozí.
- **Dlouhý formát `datum,nazev,cena`** — každé uložení ceny je nový řádek, takže přidání dalšího produktu nemění strukturu souboru. V širokém formátu (sloupec pro každý produkt) by každý nový produkt znamenal nový sloupec. Daní je, že soubor roste o řádek za každý produkt při každém uložení.
- **Playwright s `headless=False`** — Alza blokuje jednoduché stahování stránky (`requests`) i prohlížeč bez okna (Cloudflare ochrana). Funkční bylo až spuštění prohlížeče s oknem. Kvůli tomu potřebuje Docker verze virtuální displej `Xvfb`.
- **`polozky.yaml` jako jediné místo pravdy** — o tom, které produkty se sledují a zobrazují v dashboardu, rozhoduje jen tenhle soubor. Původně bral dashboard produkty z historie v CSV, takže v něm zůstával i produkt, který jsem už nesledoval. Teď stačí upravit `polozky.yaml` a historie v CSV zůstane zachovaná.
- **Docker verze jako ukázka** — pro dlouhodobé sledování cen by musel server běžet měsíce. Nedávalo mi smysl kvůli tomu nechávat zapnutý další počítač, když stejnou práci dělá plánovač úloh na počítači, který běží tak jako tak. Docker verze proto slouží jako ukázka kontejnerizace a CI/CD, ne jako ostrý provoz.

## Etická poznámka ke scrapingu

Před spuštěním jsem se přes sociální sítě zeptal na proveditelnost a etickou stránku scrapingu. Oficiální účet Alza.cz mi na dotaz ohledně osobního, nízkoobjemového monitoringu cen odpověděl, že v takhle malém rozsahu nemají námitky.

## Použití AI

Většinu projektu (scraper, ukládání a kontrola cen, alerty, testy) jsem psal sám s pomocí AI asistenta, který mě vedl a opravoval chyby, ale kód jsem psal vždy já. Výjimkou jsou soubory `report_data.py`, `grafy_cen.py` a `report_html.py`, kterou navrhla a napsala přímo AI. Sestavování grafů a HTML reportu mě nebavilo, ale zároveň jsem chtěl mít v projektu hezký přehledový dashboard, takže jsem se rozhodl tuhle část nechat na AI.
