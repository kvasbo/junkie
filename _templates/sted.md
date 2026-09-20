---
# Sted. Filnavnet (uten .md) er slug og URL: _steder/kebab-huset.md -> /steder/kebab-huset/
# Anmeldelser peker på stedet med `venue: kebab-huset`.
title: Kebab Huset                 # Stedets navn (påkrevd)
categories: [kebab, pizza]         # Slugs fra _data/kategorier.yml (kebab, pizza, taco, polse, annet)
bydel: gronland                    # Slug fra _data/bydeler.yml (valgfri, ukjent slug fungerer også)
address: Grønlandsleiret 1, 0190 Oslo
lat: 59.9127                       # Koordinater (bin/sted henter dem fra Google Places)
lng: 10.7617
google_place_id:                   # Valgfri
google_maps_url:                   # Valgfri – lenke vises under adressen
opening_hours:                     # Valgfri liste med tekstlinjer
  - "mandag: 11:00–23:00"
  - "tirsdag: 11:00–23:00"
cover_image:                       # Valgfri, f.eks. /assets/img/steder/kebab-huset/fasade.jpg (brukes som OG-bilde)
score_override:                    # Tom = automatisk (høyeste rett-score). 0–3 for å overstyre.
status: open                       # open | closed
closed_at:                         # YYYY-MM når stedet la ned (kun ved status: closed)
---
Redaksjonell kommentar i markdown. Valgfri – slett teksten hvis du ikke har noe å si om stedet som helhet.
