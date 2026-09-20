# Junkie — Produktspesifikasjon v2.0

## Konsept

**Junkie** er en redaksjonell gatemat-guide for Oslo — en "Michelin-guide for kebab." Kvalitetssikrede anmeldelser av enkelt-retter fra gatekjøkken, kebabsjapper, pizzasteder og tacobarer. Tre stjerner, ingen bullshit.

---

## Implementasjon: statisk side (Jekyll på Cloudflare Pages)

> Lagt til etter at spesifikasjonen under ble skrevet. Spesifikasjonen beskriver en Rails-app; den er i stedet realisert som en statisk Jekyll-side hostet på Cloudflare Pages. Innholdsmodellen, scoringen, IA-en og den visuelle retningen er beholdt. Se [README.md](README.md) for hvordan siden bygges og hvordan innhold skrives.

Valg tatt for den statiske utgaven:

- [x] **Innhold:** Markdown-filer i git. Én fil per sted (`_steder/`), anmeldelse (`_anmeldelser/`) og kuratert liste (`_lister/`). Ingen CMS eller admin-UI – redigering skjer i editor eller på GitHub.
- [x] **Utkast/publisert/arkivert:** `status`-felt i front matter. Utkast vises lokalt med merking, aldri i produksjon.
- [x] **Bilder:** Originaler i repoet under `assets/img/`. Resizing via Cloudflare Image Transformations (`/cdn-cgi/image/…`) i produksjon; erstatter imgproxy + R2.
- [x] **Søk:** Klientside-søk mot en JSON-indeks generert ved bygg (`/sok.json`). Erstatter FTS5.
- [x] **Kart:** Leaflet (selvhostet) med OSM-fliser, data fra `/steder.json`.
- [x] **Stedsdata:** Manuell front matter. `bin/sted` henter navn, adresse, koordinater og åpningstider fra Google Places API (New) og skriver ut front matter.
- [x] **Kategori-, tag- og bydelssider:** Genereres av en Jekyll-plugin (`_plugins/junkie.rb`) som også regner ut steds-score, anbefalt rett, ankerpunkter og feed.
- [x] **Deploy:** Cloudflare Pages med git-integrasjon. `bundle exec jekyll build`, output `_site`, `JEKYLL_ENV=production`. Ruby-versjon fra `.ruby-version`.
- [x] **Typografi:** Lilita One (OFL) selvhostet for overskrifter, system-sans for brødtekst.
- [x] **Auth, brukere, Litestream, SQLite, Kamal, DigitalOcean:** Utgår – ikke relevant for en statisk side.
- [x] **RSS og sitemap:** Med fra start (Atom-feed på `/feed.xml`, `sitemap.xml` via jekyll-sitemap).
- [x] **Eksempelinnhold:** Ingen. Maler med alle felter ligger i `_templates/`, `bin/ny` lager nye filer fra dem.
- [x] **Forsiden:** Intro-tekst og arbeidslista «Steder som testes nå» (`_data/testes.yml`) i tillegg til feeden.

## Visjon

Bli den autoritative stemmen for gatemat i Oslo. Når noen googler "beste kebab Grønland" skal Junkie dukke opp. På sikt: ekspansjon til flere byer, flere anmeldere, og en merkevare folk stoler på.

---

## Målgruppe

Alle som spiser gatemat i Oslo — fra studenter som vil ha mest mulig for hundrelappen til foodies som jakter den perfekte falafel-wrapen. Mobil-first publikum som scroller i køen eller på trikken.

---

## Kjernemodell

### Todelt innholdsstruktur

```
Sted (venue)
 ├── Kategorier (mange: kebab, pizza, osv.)
 ├── Status (åpen / nedlagt)
 ├── Score (1–3, auto fra beste rett, kan overstyres)
 ├── Redaksjonell kommentar (valgfri)
 ├── Anbefalt rett (auto: høyest score)
 └── Anmeldelser (reviews) — én per rett, revisits mulig
      ├── Bilder (valgfritt)
      ├── Score (1–3 stjerner)
      ├── Besøkt (måned + år)
      ├── Tekst (markdown, 2–5 setninger)
      └── Tags (fritt definerte, inkl. halal/vegetar/vegan)

Kuratert liste
 ├── Tittel + intro
 └── Håndplukkede anmeldelser i rekkefølge
```

**Sted** er det leseren leter etter. Kan ha flere kategorier (en sjapp selger ofte både kebab og pizza). Har sin egen score og kan ha en redaksjonell oppsummering. Steder som legger ned merkes som "nedlagt" — anmeldelsene blir værende som arkiv.

**Anmeldelse** er kjerneinnholdet: én rett fra ett sted. Kort og poengtert (2–5 setninger). Samme rett kan anmeldes på nytt som en "revisit" — alle revisits vises som en tidslinje på steds-siden. Anmeldelser har ingen egen URL — steds-siden er den eneste innholdssiden. Bilder er valgfritt. Status: utkast → publisert → arkivert.

**Kuratert liste** er redaksjonelt innhold: "Topp 5 kebab i Oslo", "Beste sen-natt-mat". Håndplukket rekkefølge, egen tittel og intro. Viktig for SEO.

---

## Scoringssystem — Tre stjerner

| Score | Betydning | Visuelt |
|-------|-----------|---------|
| ☆☆☆ | Anmeldt, men ikke anbefalt | Grå |
| ★☆☆ | God — verdt et besøk | Bronse |
| ★★☆ | Veldig god — definitivt verdt en tur | Sølv/blå |
| ★★★ | Eksepsjonell — dette MÅ du prøve | Gull |

Ingen halvstjerner. Ingen 7/10. Inspirert av Michelin-guiden — stjerner er anbefalinger, null stjerner betyr at stedet er besøkt men ikke nådde opp.

### To nivåer av score

**Rett-score** — settes av anmelder på hver anmeldelse. Er selve dommen.

**Steds-score** — default: høyeste rett-score. Kan overstyres manuelt. Et sted med én ★★★-kebab og to ★☆☆-pizzaer får ★★★ automatisk, fordi det finnes en grunn til å gå dit. Anmelderen kan nedjustere om helhetsinntrykket tilsier det.

---

## Tags / Kategorisering

Fritt definerte tags som bygger opp et folksonomi over tid. Eksempler:

- **Rett-type:** kebab, falafel, pizza, pølse, taco, burger, döner
- **Kvaliteter:** hjemmelaget pita, farse, kjøttdeig, standard oslobab, sprø bunn
- **Kosthold:** halal, vegetar, vegan
- **Meta:** sen-natt, lunsjdeal, stor porsjon, bra pris

Tags er søkbare og filtrerbare. Anmelderen oppretter nye tags fritt. Kostholdstags (halal, vegetar, vegan) er vanlige tags — ikke egne felter.

---

## Brukerroller

| Rolle | Kan |
|-------|-----|
| **Leser** (alle) | Bla, søke, filtrere, se kart |
| **Anmelder** (godkjent) | Alt over + publisere anmeldelser |
| **Admin** (deg) | Alt over + godkjenne anmeldere, moderere, redigere alt |

**MVP:** Kun admin-anmelder. Støtte for flere godkjente anmeldere bygges inn fra start i datamodellen, men UI-flyten (søknad, godkjenning) kan vente.

**Senere:** Brukerkommentarer og bruker-ratings på anmeldelser.

---

## Funksjoner — MVP

### For leseren

1. **Forsiden / Feed** — Siste anmeldelser i kronologisk rekkefølge, maks én per sted. Hvert kort viser: bilde (hvis det finnes), rettens navn, stedets navn, score, bydel, utdrag av tekst. Klikk → steds-siden med ankerpunkt til retten.

2. **Steds-side** — Stedets score, redaksjonell kommentar (hvis den finnes), anbefalt rett (høyest score), adresse, kart-pin, åpningstider, og alle anmeldte retter med revisit-tidslinje. Nedlagte steder merkes tydelig. Anmeldelser uten bilde viser farget bakgrunn med score-badge. Hver rett har et ankerpunkt (`#rett-slug`) for direktelenking.

3. **Kategori-side** — Viser steder med valgt kategori (kebab, pizza, taco, pølse, annet). Klikk → steds-siden.

4. **Tag-side** — Viser steder som har anmeldelser med gitt tag, med utdrag av den relevante anmeldelsen. Klikk → steds-siden med ankerpunkt til retten.

5. **Søk** — Fritekst-søk på stedsnavn, rettens navn, og tags.

6. **Kart** — Alle anmeldte steder på et kart. Fargekoding etter beste score. Klikk → steds-siden.

7. **Bydel-side** — Steder per bydel. Klikk → steds-siden.

### For anmelderen (admin, desktop-optimalisert)

8. **Opprett/rediger sted** — Søk via Google Places for å hente navn, adresse, koordinater og åpningstider automatisk. Legg til kategorier, bydel, redaksjonell kommentar (valgfri), manuell score-overstyring (valgfri).

9. **Skriv anmeldelse** — Velg sted → skriv markdown → sett score → velg besøksmåned → legg til tags → (valgfritt) last opp bilder → lagre som utkast eller publiser.

10. **Rediger / arkiver** — Endre publisert innhold, eller arkiver (fjerner fra offentlig visning uten å slette).

11. **Kuraterte lister** — Opprett liste med tittel og intro, håndplukk anmeldelser i ønsket rekkefølge.

---

## Funksjoner — Fase 2 (etter MVP)

- Brukerkommentarer på anmeldelser
- Bruker-ratings ("enig / uenig" eller egen stjerne)
- Flere godkjente anmeldere med profil-sider
- Nyhetsbrev / RSS
- Push-varsler for nye anmeldelser
- Ekspansjon til andre byer (aktivere geo-modellen i UI)
- Samarbeidspartnere / sponsede innlegg (tydelig merket)
- Instagram-integrasjon (auto-post ved publisering)
- Flerspråklig støtte (engelsk)

---

## Informasjonsarkitektur

```
junkie.no
├── /                          Forsiden — feed med siste anmeldelser
├── /steder                    Alle steder (liste + kart)
├── /steder/:slug              Steds-side (alle anmeldelser, revisit-tidslinjer)
├── /kategori/:type            Kebab / Pizza / Taco / Pølse / Annet
├── /tag/:tag                  Alle steder med anmeldelser med gitt tag
├── /bydel/:bydel              Steder per bydel
├── /lister                    Alle kuraterte lister
├── /lister/:slug              Enkelt kuratert liste
├── /kart                      Fullskjerm-kart
├── /om                        Om Junkie
└── /admin                     CMS for anmeldere (desktop)
```

---

## Datamodell (Rails)

```ruby
# === GEOGRAFI (ikke eksponert i UI for MVP — kun Oslo) ===

# Land
Country
  - name: string           # "Norge"
  - slug: string (unique)  # "norge"
  - code: string (2)       # "NO" (ISO 3166-1)
  - has_many :cities

# By
City
  - country_id: references
  - name: string           # "Oslo"
  - slug: string (unique)  # "oslo"
  - latitude: decimal      # senterpunkt for kart
  - longitude: decimal
  - has_many :neighborhoods
  - has_many :venues

# Bydel (valgfritt — Venue kan kobles direkte til City)
Neighborhood
  - city_id: references
  - name: string           # "Grønland"
  - slug: string (unique)  # "gronland"
  - has_many :venues

# === KJERNEINNHOLD ===

# Sted
Venue
  - city_id: references              # påkrevd
  - neighborhood_id: references      # valgfritt (nullable)
  - name: string
  - slug: string (unique)
  - address: string
  - latitude: decimal
  - longitude: decimal
  - google_maps_url: string
  - google_place_id: string          # for å oppdatere data fra Google Places
  - opening_hours: json              # hentet fra Google Places, nullable
  - summary: text                    # redaksjonell kommentar (valgfri, markdown)
  - cover_image: attached (ActiveStorage) # manuelt valgt, brukes for OG-bilde
  - score_override: integer (1-3)    # nullable — overstyrer auto-score
  - status: enum (open, closed)      # default: open
  - closed_at: date                  # nullable — når stedet la ned
  - has_many :venue_categories
  - has_many :categories, through: :venue_categories
  - has_many :reviews
  #
  # Utledede felter (ikke lagret, beregnet):
  #   auto_score       → highest published review score
  #   score            → score_override || auto_score
  #   featured_review  → published review with highest score
  #
  # Auto-arkivering: hvis alle reviews arkiveres,
  # settes venue til usynlig (ingen publiserte reviews å vise).
  # Callback: after_save på Review sjekker om venue har 0 published reviews.

# Kategori (kebab, pizza, taco, pølse, annet)
Category
  - name: string (unique)    # "Kebab"
  - slug: string (unique)    # "kebab"
  - has_many :venue_categories
  - has_many :venues, through: :venue_categories

# VenueCategory (join — et sted kan ha flere kategorier)
VenueCategory
  - venue_id: references
  - category_id: references

# Anmeldelse
Review
  - venue_id: references
  - user_id: references
  - title: string              # rettens navn, f.eks. "Kebab stor m/hvitløk"
  - anchor_slug: string        # auto: title + visited_at, f.eks. "kebab-stor-2026-03"
  - body: text                 # markdown, typisk 2–5 setninger
  - score: integer (1-3)
  - visited_at: date           # måned + år (dag settes til 1.)
  - status: enum (draft, published, archived) # default: draft
  - published_at: datetime
  - has_many :review_images
  - has_many :taggings
  - has_many :tags, through: :taggings
  #
  # Ankerpunkt: brukes som #fragment i URL-er fra feed, tags, lister.
  # Unik innenfor venue (unique: [:venue_id, :anchor_slug]).
  # Immutable etter publisering.
  #
  # Revisits: samme title + venue = revisit.
  # Vises kronologisk på steds-siden.
  # scope :for_dish, ->(title) { where(title: title) }

# Bilde (valgfritt — en review kan ha 0 eller flere)
ReviewImage
  - review_id: references
  - image: attached (ActiveStorage)
  - position: integer      # rekkefølge
  - alt_text: string

# Tag
Tag
  - name: string (unique)
  - slug: string (unique)
  - has_many :taggings
  - has_many :reviews, through: :taggings

# Tagging (join)
Tagging
  - review_id: references
  - tag_id: references

# === KURATERTE LISTER ===

# Kuratert liste ("Topp 5 kebab i Oslo")
CuratedList
  - user_id: references
  - title: string              # "Topp 5 kebab i Oslo"
  - slug: string (unique)
  - intro: text                # markdown
  - published_at: datetime
  - has_many :curated_list_items

# ListeElement (join med rekkefølge og valgfri kommentar)
CuratedListItem
  - curated_list_id: references
  - review_id: references
  - position: integer          # håndplukket rekkefølge
  - note: text                 # valgfri kommentar spesifikk for listen

# === BRUKERE ===

# Bruker
User
  - name: string
  - email: string
  - role: enum (admin, reviewer, reader)
  - bio: text
  - avatar: attached (ActiveStorage)
```

> **Merk:** For MVP hardkodes alt til Oslo/Norge. URL-strukturen bruker ikke by/land ennå. Når flere byer aktiveres senere, utvides URL-ene til f.eks. `/oslo/steder/:slug` eller `oslo.junkie.no`.

---

## Visuell retning

**Stil:** Lekent, fargerikt, pop-art-inspirert. Dark mode følger OS-innstilling.

| Element | Retning |
|---------|---------|
| **Fargepalett** | Sterke primærfarger — hot pink, electric yellow, neon-grønn. CSS custom properties for enkel theming + dark mode. Neonfarger på mørk bakgrunn i dark mode. |
| **Typografi** | En tung, bold display-font for overskrifter (tenk Cooper Black, Lobster, eller noe chunky). Ren sans-serif for brødtekst. |
| **Bilder** | Store, saftige matbilder via imgproxy (on-the-fly resizing). Anmeldelser uten bilde: farget bakgrunn med score-badge. |
| **OG-bilder** | Med bilde: auto-generert fra første bilde + Junkie-logo overlay. Uten bilde: plattformens default. |
| **Ikoner/illustrasjoner** | Håndtegnede eller pop-art-stil ikoner for kategorier (kebab-ikon, pizza-slice, osv.) |
| **Tone of voice** | Uformelt, morsomt, ærlig. Snakker som en kompis som vet hvor du skal spise. |
| **Tilgjengelighet** | Skip-links, ARIA-attributter, god fargekontrast (WCAG AA), semantisk HTML, alt-tekst på bilder. |
| **Logo** | Trengs — skal designes. |

---

## Teknisk stack

| Lag | Teknologi |
|-----|-----------|
| **Backend** | Ruby on Rails 8 |
| **Database** | SQLite (dev + prod) med solid_queue, solid_cache, solid_cable |
| **Bilder** | ActiveStorage + Cloudflare R2 |
| **Bildebehandling** | imgproxy (selvhostet, on-the-fly resizing fra R2) |
| **Frontend** | Hotwire (Turbo + Stimulus) — ingen SPA-rammeverk |
| **CSS** | SCSS via cssbundling-rails (BEM-light klassenavn) |
| **Tekst** | Markdown (rendret med redcarpet eller commonmarker) |
| **Kart** | Leaflet (open source) |
| **Søk** | SQLite FTS5 (MVP) → Meilisearch senere om nødvendig |
| **Auth** | Devise |
| **Hosting** | Kamal + DigitalOcean VPS |
| **Backup** | Litestream (continuous replication til R2) |
| **Stedsdata** | Google Places API (navn, adresse, åpningstider) |
| **Språk** | Norsk (i18n-klar for fremtiden) |

---

## MVP-scope og prioritering

### Must have (uke 1–3)
- [ ] Venue CRUD med multi-kategori og status (admin)
- [ ] Review CRUD med markdown, score, besøksdato, valgfri bildeopplasting, draft/published/archived (admin)
- [ ] Tag-system
- [ ] Devise-autentisering (registrering stengt, admin seeder bruker)
- [ ] Forsiden med feed (farget placeholder + score-badge for anmeldelser uten bilde)
- [ ] Steds-sider (auto-score, anbefalt rett, redaksjonell kommentar, revisit-tidslinje)
- [ ] Kategori- og tag-filtrering
- [ ] Responsivt design (mobil-first leser, desktop-first admin)
- [ ] Dark mode (følger OS)
- [ ] Tilgjengelighet (skip-links, ARIA, kontrast, semantisk HTML)
- [ ] Grunnleggende SEO (meta-tags, Open Graph med auto-generert bilde, schema.org/Restaurant + Review)
- [ ] imgproxy for bildeservering
- [ ] Seed-data for utvikling (geo-data + eksempel-steder/anmeldelser)
- [ ] Litestream (continuous replication av SQLite til R2)

### Should have (uke 3–5)
- [ ] Kart-visning med alle steder
- [ ] Bydel-navigasjon
- [ ] Fritekst-søk
- [ ] Kuraterte lister (CRUD + offentlige sider)
- [ ] Nedlagt-merking på steder
- [ ] Bildegalleri med swipe på mobil

### Nice to have (etter lansering)
- [ ] RSS-feed
- [ ] Social sharing-knapper med generert preview-bilde
- [ ] Sitemap for Google
- [ ] Analytics (Plausible/Umami)

---

## Lanseringsstrategi

**Stille lansering.** Bygge innhold først, dele når det er 20+ anmeldelser. Eneste distribusjonskanal er organisk søk (Google/SEO). Ingen sosiale medier-kanaler for MVP.

**Innholdsstrategi:** Backfill en batch med 15–20 anmeldelser fra hukommelsen (uten bilder), deretter fortløpende nye anmeldelser med bilder fra nye besøk. Mål: 20+ publiserte anmeldelser før deling.

Dette betyr at teknisk SEO er kritisk fra dag 1: schema.org structured data, rask lastetid, gode URL-er, og Open Graph for deling.

---

## Suksesskriterier for MVP

1. **Publisert med 20+ anmeldelser** — nok innhold til at det føles som en ekte guide.
2. **Fungerer perfekt på mobil** — 80%+ av trafikken vil være mobil.
3. **Rask** — under 2 sekunder lastetid. imgproxy + R2 er kritisk.
4. **Delbart** — hvert sted har en god URL og pen Open Graph-preview.
5. **Googles det, finner du det** — SEO fra dag 1.
6. **Tilgjengelig** — WCAG AA fra start.

---

## Beslutninger tatt

- [x] **Domene:** junkie.no
- [x] **Geo-modell:** Country → City → Neighborhood (valgfritt). Venue alltid på City, kan ha Neighborhood. Ikke eksponert i MVP.
- [x] **CSS:** SCSS med semantiske klassenavn (BEM-light), ingen Tailwind.
- [x] **Database:** SQLite overalt (dev + prod). Søk via FTS5. Ingen Postgres.
- [x] **Sted vs. rett:** Anmeldelser er per rett, stedet er den eneste innholdssiden. Ingen separate anmeldelses-URL-er.
- [x] **Anbefalt rett:** Automatisk den med høyest score.
- [x] **Bilder:** Valgfritt. Uten bilde: farget bakgrunn + score-badge i feed.
- [x] **Kategorier:** Many-to-many — et sted kan ha flere kategorier.
- [x] **Pris:** Grov indikator per rett (kr / kr kr / kr kr kr).
- [x] **Besøksdato:** Måned + år, separat fra publiseringsdato.
- [x] **Revisits:** Tidslinje under steds-siden — én URL per sted, alle revisits samlet. Best for SEO.
- [x] **Review-status:** Utkast → publisert → arkivert. Tre-stegs workflow.
- [x] **Nedlagte steder:** Merkes som "nedlagt", uavhengig av review-status. Anmeldelser kan være publisert på nedlagte steder.
- [x] **Arkiverte reviews i lister:** Forblir i kuratert liste med visuell markering.
- [x] **Kosthold:** Halal, vegetar, vegan håndteres som vanlige tags.
- [x] **Kuraterte lister:** Egen innholdstype med tittel, intro og håndplukket rekkefølge.
- [x] **Tekst:** Markdown for anmeldelser og redaksjonell kommentar.
- [x] **Auth:** Devise, registrering stengt. Admin oppretter brukere. Seed admin-bruker.
- [x] **Hosting:** Kamal + DigitalOcean VPS.
- [x] **Bildelagring:** Cloudflare R2 (ingen egress-kostnader).
- [x] **Bildebehandling:** imgproxy (selvhostet, on-the-fly resizing).
- [x] **Slugs:** Auto-generert med mulighet for overstyring. Immutable etter publisering.
- [x] **Admin-UX:** Desktop-optimalisert. Anmeldelser skrives hjemme etterpå.
- [x] **OG-bilder:** Steds-side: manuelt valgt cover image + logo-overlay. Uten cover image: plattformens default.
- [x] **Dark mode:** Følger OS-innstilling via CSS custom properties.
- [x] **Tilgjengelighet:** Skip-links, ARIA, WCAG AA kontrast, semantisk HTML fra start.
- [x] **Brukerkontoer:** Ingen registrering eller brukerkontoer i MVP. Ren leseside.
- [x] **Caching:** Ingen for MVP — optimaliseres etter behov.
- [x] **Backup:** Litestream — continuous replication av SQLite til R2. Null datatap.
- [x] **Seed-data:** Ja — geo-data + eksempel-steder/anmeldelser for utvikling.
- [x] **Logo:** Trengs — skal designes.
- [x] **Språk:** Norsk.
- [x] **Lansering:** Stille, ved 20+ anmeldelser. Kun organisk SEO.
- [x] **Innholdsstrategi:** Backfill fra hukommelsen + fortløpende nye.
- [x] **Anmeldelseslengde:** Kort og poengtert, 2–5 setninger.
- [x] **Analytics:** Ingenting for MVP.
- [x] **Inntekt:** Ikke prioritert ennå — fokus på produkt.
- [x] **Google Places:** Ja — hente navn, adresse, åpningstider automatisk ved opprettelse av sted.
- [x] **URL-strategi for flere byer:** Bestemmes når det blir aktuelt. Geo-modellen er klar i backend.
- [x] **Kart:** Leaflet (gratis, open source).
- [x] **Tag/kategori/bydel-sider:** Viser steds-liste. Tags lenker med ankerpunkt til relevant rett på steds-siden.
- [x] **Feed:** Maks én anmeldelse per sted for å unngå dominering ved bulk-publisering.
- [x] **Ankerpunkt:** Reviews har `anchor_slug` (title + besøksdato, f.eks. "kebab-stor-2026-03"). Unik innenfor venue. Immutable.
- [x] **Kuraterte lister — visning:** Steds-kort med den relevante retten highlightet.
- [x] **OG-bilde på steds-side:** Manuelt valgt cover image på stedet. Venue har `cover_image`-felt.
- [x] **Kategorier vs. tags:** Beholdes som separate konsepter. Kategorier er faste på steder, tags er frie på anmeldelser.
- [x] **Auto-arkivering:** Venue skjules automatisk når alle reviews er arkivert.

## Åpne spørsmål

Ingen — alle spesifikasjonsspørsmål er besvart. Klar for utvikling.

---

*Dokumentet er et levende dokument. Oppdater etter hvert som beslutninger tas.*
