# Junkie

Redaksjonell gatemat-guide for Oslo. «Michelin-guiden for kebab.» Statisk Jekyll-side som hostes på Cloudflare Pages.

Produktspesifikasjonen ligger i [agents.md](agents.md). Dette dokumentet beskriver hvordan siden er bygget og hvordan du skriver innhold.

## Kom i gang lokalt

Krever Ruby (se `.ruby-version`) og Bundler.

```sh
bundle install
bundle exec jekyll serve --livereload
```

Siden kjører på <http://localhost:4000>. Lokalt vises utkast (`status: draft`) med tydelig merking, slik at du kan se anmeldelsen mens du skriver. I produksjon (`JEKYLL_ENV=production`) er utkast skjult.

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

Maler med alle felter dokumentert ligger i `_templates/`. Bruk `bin/ny` for å lage nye filer fra malene:

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
lat: 59.9127
lng: 10.7617
google_maps_url: https://maps.app.goo.gl/...
opening_hours: ["mandag: 11:00–23:00", ...]
cover_image: /assets/img/steder/kebab-huset/fasade.jpg   # valgfri, brukes som OG-bilde
score_override:                # tom = auto (høyeste rett-score)
status: open                   # open | closed
closed_at: 2026-05             # ved status: closed
---
Redaksjonell kommentar i markdown (valgfri).
```

Et sted vises bare når det har minst én publisert anmeldelse. Steds-score er automatisk høyeste rett-score, med mindre `score_override` er satt. Anbefalt rett er retten med høyest score.

### Anmeldelse

```yaml
---
venue: kebab-huset             # filnavn i _steder/ uten .md
title: Kebab stor m/hvitløk    # rettens navn
score: 3                       # 0–3
price: 2                       # 1–3 (kr / kr kr / kr kr kr)
visited: 2026-03               # måned + år
date: 2026-03-15               # publiseringsdato, styrer feed-rekkefølge
status: published              # draft | published | archived
tags: [kebab, hjemmelaget pita, halal]
images:
  - src: /assets/img/anmeldelser/kebab-huset-kebab-stor-2026-03/1.jpg
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

## Bilder

Legg originalbilder i repoet:

- `assets/img/anmeldelser/<anmeldelse-filnavn>/1.jpg`, `2.jpg`, …
- `assets/img/steder/<sted-slug>/…`

Hold originalene fornuftige (maks ca. 2000 px bred, 1 MB) siden de ligger i git. I produksjon skrives alle bilde-URL-er om til Cloudflare Image Transformations (`/cdn-cgi/image/width=…/assets/img/…`) med `srcset` i flere bredder. Lokalt brukes originalen direkte.

For at dette skal virke må **Transformations** være skrudd på for sonen `junkie.no` i Cloudflare-dashbordet (Images → Transformations → Enable for zone). Gratisnivået dekker 5 000 unike transformasjoner per måned. Uten det (eller på `*.pages.dev`) returnerer `/cdn-cgi/image/` ikke bilder – sett `cloudflare_images: false` i `_config.yml` for å bruke originalene.

## Google Places

`bin/sted` slår opp et sted i Google Places API (New) og skriver ut front matter med navn, adresse, koordinater, place-id, Maps-lenke og åpningstider:

```sh
export GOOGLE_PLACES_API_KEY=...    # eller legg nøkkelen i .env (ignorert av git)
bin/sted "Syverkiosken"             # skriv ut front matter
bin/sted "Syverkiosken" --alle      # vis alle treff
bin/sted "Syverkiosken" --skriv     # skriv _steder/syverkiosken.md direkte
```

Nøkkelen må ha «Places API (New)» aktivert i Google Cloud-prosjektet.

## Deploy til Cloudflare

Siden bygges av Cloudflare Workers Builds via git-integrasjon (Workers & Pages → Create → Workers → Import a repository). Innstillinger:

| Innstilling | Verdi |
|-------------|-------|
| Build command | `bundle exec jekyll build` |
| Deploy command | `npx wrangler deploy` |
| Root directory | `/` |
| Build variable `JEKYLL_ENV` | `production` |

`wrangler.jsonc` forteller wrangler at `_site/` skal lastes opp som statiske filer, at `/steder/foo` og `/steder/foo/` er samme side, og at `404.html` brukes ved ukjente URL-er. Ruby-versjonen leses fra `.ruby-version`. Hver push til `main` deployer produksjon; andre branches får forhåndsvisnings-URL-er.

Skal du heller bruke et klassisk Pages-prosjekt: samme build command, output directory `_site`, ingen deploy command.

`_headers` setter cache- og sikkerhetsheadere. `sitemap.xml`, `robots.txt` og `feed.xml` (Atom) genereres automatisk.

Koble domenet `junkie.no` til Workeren under Settings → Domains & Routes.

## Struktur

```
_config.yml          Nettstedsinnstillinger, samlinger, kart-senter
_plugins/junkie.rb   Avledet data (score, anbefalt rett, ankere, feed) og genererte sider
_layouts/            default, sted, liste, kategori, tag, bydel
_includes/           Kort, stjerner, bilde, ikoner, JSON-LD
_sass/               Farger/tokens (lys + mørk), base, layout, komponenter, sider
assets/js/kart.js    Leaflet-kart (alle steder, ett sted)
assets/js/sok.js     Klientside-søk mot /sok.json
assets/vendor/       Leaflet 1.9.4 (selvhostet)
assets/fonts/        Lilita One (OFL, selvhostet)
_data/               kategorier, bydeler, nav, testes
_templates/          Maler for sted, anmeldelse, liste
bin/                 ny (lag filer fra mal), sted (Google Places-oppslag)
```

## Sjekkliste før lansering

- [ ] 20+ publiserte anmeldelser
- [ ] Transformations skrudd på for sonen i Cloudflare
- [ ] `junkie.no` koblet til Pages-prosjektet
- [ ] Egen logo (dagens er en enkel SVG-ordmerke i `_includes/logo.svg`, favicon i `assets/img/favicon.svg`, OG-bilde i `assets/img/og-default.png`)
