/* Junkie – klientside-søk mot /sok.json */
(function () {
  var liste = document.getElementById('sok-treff');
  var felt = document.getElementById('q');
  var status = document.getElementById('sok-status');
  if (!liste || !felt) return;

  var STJERNER = { 0: '☆☆☆', 1: '★☆☆', 2: '★★☆', 3: '★★★' };
  var TYPER = { sted: 'Sted', rett: 'Rett', tag: 'Tag' };
  var data = null;

  function norm(s) {
    return String(s || '').toLowerCase()
      .replace(/æ/g, 'ae').replace(/ø/g, 'o').replace(/å/g, 'a')
      .normalize('NFD').replace(/[̀-ͯ]/g, '');
  }
  function esc(s) {
    return String(s || '').replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  function rangér(q) {
    var ord = norm(q).split(/\s+/).filter(Boolean);
    if (!ord.length) return [];
    return data.map(function (e) {
      var navn = norm(e.n), hay = norm([e.n, e.v, e.b, e.k, e.x, e.e].join(' '));
      var poeng = 0;
      for (var i = 0; i < ord.length; i++) {
        var o = ord[i];
        if (navn === o) poeng += 10;
        else if (navn.indexOf(o) === 0) poeng += 6;
        else if (navn.indexOf(o) >= 0) poeng += 4;
        else if (hay.indexOf(o) >= 0) poeng += 1;
        else return null;
      }
      if (e.t === 'sted') poeng += 1;
      poeng += (e.s || 0) * 0.1;
      return { e: e, p: poeng };
    }).filter(Boolean).sort(function (a, b) { return b.p - a.p; }).slice(0, 60);
  }

  function vis(q) {
    if (!data) return;
    var treff = rangér(q);
    liste.innerHTML = treff.map(function (t) {
      var e = t.e, sub = '';
      if (e.t === 'rett') sub = e.v + (e.b ? ' · ' + e.b : '');
      if (e.t === 'sted') sub = e.k + (e.b ? ' · ' + e.b : '') + (e.c ? ' · nedlagt' : '');
      if (e.t === 'tag') sub = e.a + (e.a === 1 ? ' rett' : ' retter');
      return '<li class="sok-treff__el"><a href="' + esc(e.u) + '">' +
        '<span class="sok-treff__type">' + TYPER[e.t] + '</span>' +
        '<span><span class="sok-treff__navn">' + (e.t === 'tag' ? '#' : '') + esc(e.n) + '</span><br><span class="sok-treff__sub">' + esc(sub) + '</span></span>' +
        (e.s !== undefined ? '<span class="sok-treff__score stjerner stjerner--liten stjerner--' + e.s + '" aria-label="' + e.s + ' av 3 stjerner">' + STJERNER[e.s] + '</span>' : '') +
        '</a></li>';
    }).join('');
    if (status) {
      status.textContent = q.trim() ? (treff.length ? treff.length + ' treff' : 'Ingen treff på «' + q + '»') : '';
    }
    var url = new URL(window.location);
    if (q.trim()) url.searchParams.set('q', q); else url.searchParams.delete('q');
    history.replaceState(null, '', url);
  }

  var start = new URL(window.location).searchParams.get('q') || '';
  if (start) felt.value = start;

  fetch(liste.dataset.src)
    .then(function (r) { return r.json(); })
    .then(function (d) { data = d; vis(felt.value); })
    .catch(function () { if (status) status.textContent = 'Kunne ikke laste søkeindeksen.'; });

  var t;
  felt.addEventListener('input', function () { clearTimeout(t); t = setTimeout(function () { vis(felt.value); }, 80); });
  felt.form && felt.form.addEventListener('submit', function (ev) { ev.preventDefault(); vis(felt.value); });
})();
