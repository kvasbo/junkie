# Junkie

Redaksjonell gatemat-guide for Oslo. Junkfood som faktisk er verdt turen. Statisk Jekyll-side som hostes på Cloudflare (Workers static assets).

Produktspesifikasjonen ligger i [agents.md](agents.md). Dette dokumentet beskriver hvordan siden er bygget og hvordan du skriver innhold.

## Kom i gang lokalt

Krever Ruby (3.2 eller nyere) og Bundler.

```sh
bundle install
bundle exec jekyll serve --livereload
```

Siden kjører på <http://localhost:4000>. Anmeldelser er publisert med mindre du setter `status: draft`. Utkast vises lokalt med tydelig merking, slik at du kan se anmeldelsen mens du skriver, men er skjult i produksjon (`JEKYLL_ENV=production`). `bin/sjekk` minner deg på utkast som ligger og venter.

Produksjonsbygg lokalt:

```sh
JEKYLL_ENV=production bundle exec jekyll build
```

## Innholdsmodell

Alt innhold er markdown-filer i git. Tre samlinger:

| Mappe | Hva | URL |
|-------|-----|-----|
| `_steder/` | Ett sted per fil. Filnavnet er slug. | `/steder/<slug>/` |
| `_anmeldelser/` | Én rett per fil. Peker på stedet med `venue:`. | Ingen egen side – vises på steds-siden med ankerpunkt `#<rett>-<YYYY-MM>` |
| `_lister/` | Kuratert liste med håndplukkede anmeldelser. | `/lister/<slug>/` |

Enklest er den interaktive veiviseren, som spør om det viktigste og skriver ren front matter uten kommentarer:

```sh
bin/sted          # nytt sted (også kjeder med flere lokasjoner) + valgfri første anmeldelse
```

Med `GOOGLE_MAPS_API_KEY` satt (samme nøkkel som [Google Maps-synken](#google-maps-synk), i miljøet eller i `.env` i rotmappa) spør veiviseren først om Google place ID og henter navn, adresse, koordinater, Maps-lenke og bydel (hvis den finnes i `_data/bydeler.yml`) derfra, så du bare bekrefter med Enter. Place ID finner du med Googles [Place ID Finder](https://developers.google.com/maps/documentation/places/web-service/place-id#find-id). Uten nøkkel, eller med tomt svar, fyller du inn for hånd: koordinater kan limes inn som «59.912, 10.765» eller som en Google Maps-URL. Alternativt lager `bin/ny` filer fra malene i `_templates/`, med alle felter dokumentert i kommentarer:

```sh
bin/ny sted "Kebab Huset"                    # _steder/kebab-huset.md
bin/ny anmeldelse kebab-huset "Kebab stor"   # _anmeldelser/kebab-huset-kebab-stor-2026-09.md
bin/ny liste "Topp 5 kebab i Oslo"           # _lister/topp-5-kebab-i-oslo.md
```

### Sted

```yaml
---
title: Kebab Huset
categories: [kebab, pizza]     # slugs fra _data/kategorier.yml
bydel: gronland                # slug fra _data/bydeler.yml (valgfri)
address: Grønlandsleiret 1, 0190 Oslo
lat: 59.9127                   # høyreklikk i Google Maps for å kopiere
lng: 10.7617
google_maps_url: https://maps.app.goo.gl/...
google_place_id: ChIJ...       # fylles inn av Google Maps-synken
cover_image: /assets/img/steder/kebab-huset/fasade.jpg   # valgfri, brukes som OG-bilde
score_override:                # tom = auto (høyeste rett-score)
status: open                   # open | closed
closed_at: 2026-05             # ved status: closed
---
Redaksjonell kommentar i markdown (valgfri).
```

Et sted med flere lokasjoner (kjeder) bruker `locations:` i stedet for `address`/`lat`/`lng`/`bydel`. Alle lokasjonene deler anmeldelser, score og URL, vises som egne nåler på kartet og gjør at stedet dukker opp i alle bydelene sine:

```yaml
locations:
  - name: Kirkeristen
    address: Kirkeristen 3, 0153 Oslo
    lat: 59.9124
    lng: 10.7460
    bydel: sentrum
    status: closed               # valgfri, per lokasjon
  - name: Grønland
    address: Grønlandsleiret 15, 0190 Oslo
    lat: 59.9127
    lng: 10.7617
    bydel: gronland
```

Et sted vises bare når det har minst én publisert anmeldelse. Steds-score er automatisk høyeste rett-score, med mindre `score_override` er satt. Boksen «Anmeldt» på steds-siden lister alle anmeldte retter; på kort vises retten med høyest score.

### Anmeldelse

```yaml
---
venue: kebab-huset             # filnavn i _steder/ uten .md
title: Kebab stor m/hvitløk    # rettens navn
score: 3                       # 0–3
visited: 2026-03               # måned + år
date: 2026-03-15               # publiseringsdato, styrer feed-rekkefølge
status: published              # published (standard) | draft | archived
tags: [kebab, hjemmelaget pita, halal]
images:
  - src: /assets/img/anmeldelser/kebab-huset-202603.jpg
    alt: Kebab i pita
---
To til fem setninger i markdown.
```

Samme `venue` + samme `title` = revisit. Alle besøk vises som tidslinje under retten på steds-siden, nyeste først. Ankerpunktet er `<rett-slug>-<YYYY-MM>` og kan overstyres med `anchor:`.

Arkiverte anmeldelser (`status: archived`) forsvinner fra steds-siden, men blir stående i kuraterte lister med merking.

### Kuratert liste

```yaml
---
title: Topp 5 kebab i Oslo
date: 2026-04-01
status: published
items:
  - review: kebab-huset-kebab-stor-2026-03    # filnavn i _anmeldelser/ uten .md
    note: Valgfri kommentar for denne lista.
---
Intro i markdown.
```

### Kategorier, bydeler og tags

- Kategorier er faste og ligger i `_data/kategorier.yml`. Ikoner tegnes i `_includes/ikon.html`.
- Bydeler/strøk ligger i `_data/bydeler.yml`. Ukjente slugs fungerer også.
- Tags er frie tekststrenger på anmeldelser. Sider under `/tag/<slug>/` genereres automatisk.
- «Steder som testes nå» på forsiden styres av `_data/testes.yml`. Steder som har fått en publisert anmeldelse, lenkes automatisk og hakes av.
- Forsiden viser de `feed_per_page` (24) nyeste anmeldelsene, maks én per sted. Eldre havner på `/side/2/`, `/side/3/` osv.
- `/steder/` kan sorteres (score, navn, sist anmeldt) og filtreres på bydel og kategori, klientside. Valgene ligger i URL-en (`/steder/?bydel=gronland`), så de kan deles.

## Bilder

Legg bilder i repoet og referer til dem fra front matter:

- `assets/img/anmeldelser/<sted>-<YYYYMM>.jpg` – alle anmeldelsesbilder ligger flatt i samme mappe
- `assets/img/steder/<sted-slug>/…`

Bredde og høyde leses ut av filene ved bygg og settes på `<img>`, så siden ikke hopper mens bildene laster. Bildene serveres som de er, uten resizing. Skaler dem ned selv før du sjekker inn (rundt 1600 px bred og under 500 kB er et greit mål), både for lastetid og fordi de ligger i git.

## Sjekk før push

```sh
bin/sjekk
```

Kjører et produksjonsbygg til en midlertidig mappe og lister problemer: bilder som er referert men ikke finnes, score utenfor 0–3, ugyldig `visited`, anmeldelser som peker på ukjente steder, to anmeldelser med samme anker, lister som peker på ukjente anmeldelser, kategorier som ikke finnes i `_data/kategorier.yml`, og tags skrevet med ulik stavemåte. Feil stopper produksjonsbygget (også hos Cloudflare); advarsler gjør det ikke. Lokalt med `jekyll serve` vises alt bare som advarsler.

## Google Maps-synk

`bin/google-sync` holder stedene i `_steder/` i takt med Google Maps via Places API (New). For hver lokasjon som ikke er nedlagt:

- finner stedet hos Google (søk på navn + adresse, treffet må ligge innen 300 m fra koordinatene våre) og lagrer `google_place_id`
- oppdaterer `lat`/`lng` hvis Google plasserer stedet mer enn 30 m unna
- fyller inn `address` og `google_maps_url` hvis de mangler (en adresse du har skrevet selv, overstyres aldri)
- setter `status: closed` og `closed_at` når Google melder stedet permanent stengt

Tittel, kategorier, bydel og tekst røres aldri. Midlertidig stengte steder og steder som ikke blir funnet, listes som advarsler. Sett `google_sync: false` i front matter for å holde et sted (eller én lokasjon) utenfor, eller legg inn `google_place_id` for hånd hvis søket bommer.

Workflowen `.github/workflows/google-sync.yml` kjører skriptet hver mandag morgen, ved push til `main` som endrer `_steder/`, og manuelt fra Actions-fanen (kryss av «dry_run» for bare å se endringene i kjøringens oppsummering). Endringer committes rett til `main` av `github-actions[bot]` og deployes som vanlig; oppsummeringen av hver kjøring viser hva som ble endret. Endres mer enn 20 % av stedene i én kjøring, havner endringene i stedet på grenen `google-sync` med en pull request mot `main`, så du får sett over før noe publiseres. Oppsett, én gang:

1. Lag en API-nøkkel i Google Cloud Console med «Places API (New)» aktivert, og begrens nøkkelen til det API-et.
2. Legg den inn som repo-secret `GOOGLE_MAPS_API_KEY` (Settings → Secrets and variables → Actions).
3. Kryss av «Allow GitHub Actions to create and approve pull requests» (Settings → Actions → General → Workflow permissions). Trengs bare for pull request-tilfellet.

Lokalt:

```sh
echo 'GOOGLE_MAPS_API_KEY=...' > .env                     # én gang; .env er gitignorert og leses av bin/sted og bin/google-sync
bin/google-sync --dry-run                                 # vis hva som ville blitt endret
bin/google-sync sultan                                    # bare ett sted
```

## Markdown for maskiner

Alt innhold finnes også som ren markdown, generert ved bygg:

- Hver steds-, tag-, bydels- og listeside har en tvilling der avsluttende `/` er byttet ut med `.md`, f.eks. `/steder/sultan.md`. HTML-sidene peker på den med `<link rel="alternate" type="text/markdown">`.
- `/llms.txt` er en indeks med intro, skala og lenker til alle markdown-sidene (konvensjonen fra llmstxt.org).
- `/llms-full.txt` er hele guiden i én fil.
- `/om.md` er om-siden.

`robots.txt` tillater eksplisitt de vanlige KI-crawlerne. Sjekk at Cloudflare ikke blokkerer dem for sonen (Security → Bots → AI bots).

## Deploy til Cloudflare

Siden bygges av Cloudflare Workers Builds via git-integrasjon (Workers & Pages → Create → Workers → Import a repository). Innstillinger:

| Innstilling | Verdi |
|-------------|-------|
| Build command | `bundle exec jekyll build` |
| Deploy command | `npx wrangler deploy` |
| Root directory | `/` |
| Build variable `JEKYLL_ENV` | `production` |

`wrangler.jsonc` forteller wrangler at `_site/` skal lastes opp som statiske filer, at `/steder/foo` og `/steder/foo/` er samme side, og at `404.html` brukes ved ukjente URL-er. Ruby-versjonen er ikke pinnet, så Cloudflare bruker sin forhåndsinstallerte Ruby (3.2). Andre versjoner må kompileres i byggemiljøet og tar lang tid. Hver push til `main` deployer produksjon; andre branches får forhåndsvisnings-URL-er.

Skal du heller bruke et klassisk Pages-prosjekt: samme build command, output directory `_site`, ingen deploy command.

`_headers` setter cache- og sikkerhetsheadere. `sitemap.xml`, `robots.txt` og `feed.xml` (Atom) genereres automatisk.

Koble domenet `junkie.no` til Workeren under Settings → Domains & Routes.

## Struktur

```
_config.yml          Nettstedsinnstillinger, samlinger, kart-senter
_plugins/junkie.rb   Avledet data (score, anmeldte retter, ankere, feed) og genererte sider
_layouts/            default, sted, liste, kategori, tag, bydel
_includes/           Kort, stjerner, ikoner, JSON-LD
_sass/               Farger/tokens (lys + mørk), base, layout, komponenter, sider
assets/js/kart.js    Leaflet-kart (alle steder, ett sted)
assets/js/sok.js     Klientside-søk mot /sok.json
assets/js/steder.js  Sortering og filter på /steder/
assets/vendor/       Leaflet 1.9.4 (selvhostet)
assets/fonts/        Lilita One (OFL, selvhostet)
_data/               kategorier, bydeler, nav, testes
_templates/          Maler for sted, anmeldelse, liste
bin/                 sted (interaktiv veiviser), ny (lag filer fra mal), sjekk (valider innhold)
```

## Sjekkliste før lansering

- [ ] 20+ publiserte anmeldelser
- [ ] `junkie.no` koblet til Workeren i Cloudflare
- [ ] Egen logo (dagens er en enkel SVG-ordmerke i `_includes/logo.svg`, favicon i `assets/img/favicon.svg`, OG-bilde i `assets/img/og-default.png`)
