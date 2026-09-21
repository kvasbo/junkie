/* Junkie – sortering og filter på /steder/ (klientside, ingen avhengigheter) */
(function () {
  var form = document.getElementById('steder-filter');
  var liste = document.getElementById('steder-rutenett');
  if (!form || !liste) return;
  form.hidden = false;

  var items = Array.prototype.slice.call(liste.children);
  var antall = document.getElementById('steder-antall');
  var params = new URLSearchParams(window.location.search);
  ['sort', 'bydel', 'kat'].forEach(function (k) { if (params.get(k) && form.elements[k]) form.elements[k].value = params.get(k); });
  if (params.get('nedlagt') === '0') form.elements.skjulnedlagt.checked = true;

  function oppdater() {
    var sort = form.elements.sort.value, bydel = form.elements.bydel.value, kat = form.elements.kat.value;
    var skjul = form.elements.skjulnedlagt.checked, vist = 0;

    items.forEach(function (li) {
      var ok = (!bydel || (' ' + li.dataset.bydel + ' ').indexOf(' ' + bydel + ' ') >= 0) &&
               (!kat || (' ' + li.dataset.kat + ' ').indexOf(' ' + kat + ' ') >= 0) &&
               (!skjul || !li.dataset.nedlagt);
      li.hidden = !ok;
      if (ok) vist++;
    });

    var sorted = items.slice().sort(function (a, b) {
      if (sort === 'navn') return a.dataset.navn.localeCompare(b.dataset.navn, 'nb');
      if (sort === 'dato') return (b.dataset.dato || '').localeCompare(a.dataset.dato || '');
      var d = (parseInt(b.dataset.score, 10) || 0) - (parseInt(a.dataset.score, 10) || 0);
      return d || a.dataset.navn.localeCompare(b.dataset.navn, 'nb');
    });
    sorted.forEach(function (li) { liste.appendChild(li); });

    if (antall) antall.textContent = vist === items.length ? items.length + ' steder' : vist + ' av ' + items.length + ' steder';

    var url = new URL(window.location);
    ['sort', 'bydel', 'kat'].forEach(function (k) {
      var v = form.elements[k].value;
      if (v && !(k === 'sort' && v === 'score')) url.searchParams.set(k, v); else url.searchParams.delete(k);
    });
    if (skjul) url.searchParams.set('nedlagt', '0'); else url.searchParams.delete('nedlagt');
    history.replaceState(null, '', url);
  }

  form.addEventListener('change', oppdater);
  form.addEventListener('submit', function (e) { e.preventDefault(); oppdater(); });
  oppdater();
})();
