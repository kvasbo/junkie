---
title: Om Junkie
description: Junkie er en redaksjonell gatemat-guide for Oslo. Kebab, falafel, pølser og burger på sitt beste – når det fortsatt er sjappe.
permalink: /om/
---
<header class="side__topp">
  <h1 class="side__tittel">Om Junkie</h1>
</header>
<div class="prosa">
{% capture intro %}{% include forside-intro.md %}{% endcapture %}{{ intro | markdownify }}

## Slik fungerer stjernene

Junkie anmelder **retter**, ikke steder. Hver rett får null til tre stjerner. Stjerner er anbefalinger, og null stjerner betyr at stedet er besøkt, men ikke nådde opp. Ingen halvstjerner, ingen 7/10.

<ul class="hero__skala">
  <li>{% include stjerner.html score=3 str="liten" %} Eksepsjonell – dette MÅ du prøve</li>
  <li>{% include stjerner.html score=2 str="liten" %} Veldig god – definitivt verdt en tur</li>
  <li>{% include stjerner.html score=1 str="liten" %} God – verdt et besøk</li>
  <li>{% include stjerner.html score=0 str="liten" %} Anmeldt, men ikke anbefalt</li>
</ul>

Et sted får automatisk scoren til sin beste rett. Har sjappa én ★★★-kebab og to ★☆☆-pizzaer, er den et ★★★-sted – fordi det finnes en grunn til å gå dit. Samme rett kan anmeldes på nytt senere; alle besøkene vises som en tidslinje på steds-siden.

## Uavhengig

Ingen betalte omtaler, ingen sponsede plasseringer. Alt er spist og betalt av Junkie selv.
</div>
