---
# Sted. Filnavnet (uten .md) er slug og URL: _steder/kebab-huset.md -> /steder/kebab-huset/
# Anmeldelser peker på stedet med `venue: kebab-huset`.
title: Kebab Huset                 # Stedets navn (påkrevd)
categories: [kebab, pizza]         # Slugs fra _data/kategorier.yml (kebab, pizza, taco, polse, annet)
bydel: gronland                    # Slug fra _data/bydeler.yml (valgfri, ukjent slug fungerer også)
address: Grønlandsleiret 1, 0190 Oslo
lat: 59.9127                       # Koordinater (høyreklikk i Google Maps for å kopiere)
lng: 10.7617
google_maps_url:                   # Valgfri – lenke vises under adressen
cover_image:                       # Valgfri, f.eks. /assets/img/steder/kebab-huset/fasade.jpg (brukes som OG-bilde)
score_override:                    # Tom = automatisk (høyeste rett-score). 0–3 for å overstyre.
status: open                       # open | closed
closed_at:                         # YYYY-MM når stedet la ned (kun ved status: closed)
# Flere lokasjoner (kjeder): fjern address/lat/lng/bydel over og bruk locations i stedet.
# Alle lokasjoner deler samme anmeldelser, score og side.
# locations:
#   - name: Kirkeristen
#     address: Kirkeristen 3, 0153 Oslo
#     lat: 59.9124
#     lng: 10.7460
#     google_maps_url:
#     bydel: sentrum
#     status: closed             # open | closed per lokasjon
#     closed_at: 2024-01
#   - name: Grønland
#     address: Grønlandsleiret 15, 0190 Oslo
#     lat: 59.9127
#     lng: 10.7617
#     bydel: gronland
---
Redaksjonell kommentar i markdown. Valgfri – slett teksten hvis du ikke har noe å si om stedet som helhet.
