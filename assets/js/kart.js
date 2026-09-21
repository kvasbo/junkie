/* Junkie – kart (Leaflet). Brukes på /kart/, /steder/ og steds-sider. */
(function () {
  var el = document.getElementById('kart');
  if (!el || typeof L === 'undefined') return;

  var FARGER = { 0: '#d4d4d4', 1: '#d98b3f', 2: '#7fbcff', 3: '#ffc400' };
  var STJERNER = { 0: '☆☆☆', 1: '★☆☆', 2: '★★☆', 3: '★★★' };
  var tiles = el.getAttribute('data-tiles') || 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  el.removeAttribute('role');
  var map = L.map(el, { scrollWheelZoom: el.classList.contains('kart--full') });
  L.tileLayer(tiles, {
    maxZoom: 19,
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
  }).addTo(map);

  function marker(lat, lng, score, closed) {
    return L.circleMarker([lat, lng], {
      radius: closed ? 7 : 10,
      color: '#111',
      weight: 2.5,
      fillColor: FARGER[score] || FARGER[0],
      fillOpacity: closed ? 0.5 : 1,
      dashArray: closed ? '3 3' : null
    });
  }

  function esc(s) {
    return String(s || '').replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  // Ett sted (steds-siden): én eller flere lokasjoner i data-points
  if (el.dataset.points) {
    var pts = [];
    try { pts = JSON.parse(el.dataset.points); } catch (e) { pts = []; }
    var score = parseInt(el.dataset.score || '0', 10), b = [];
    pts.forEach(function (p) {
      marker(p.lat, p.lng, score, !!p.closed).addTo(map)
        .bindPopup('<h3>' + esc(el.dataset.navn) + (p.name ? ' · ' + esc(p.name) : '') + '</h3>' + (p.closed ? '<div><s>Nedlagt</s></div>' : ''));
      b.push([p.lat, p.lng]);
    });
    if (b.length > 1) map.fitBounds(b, { padding: [30, 30], maxZoom: 15 });
    else if (b.length === 1) map.setView(b[0], 16);
    return;
  }

  // Alle steder
  var center = (el.dataset.center || '59.9139,10.7522').split(',').map(parseFloat);
  map.setView(center, parseInt(el.dataset.zoom || '12', 10));

  fetch(el.dataset.src)
    .then(function (r) { return r.json(); })
    .then(function (data) {
      var bounds = [];
      data.filter(Boolean).forEach(function (s) {
        var m = marker(s.lat, s.lng, s.s, s.c === 1).addTo(map);
        var html = '<h3><a href="' + esc(s.u) + '">' + esc(s.n) + (s.l ? ' · ' + esc(s.l) : '') + '</a></h3>' +
          '<div>' + STJERNER[s.s] + (s.c === 1 ? ' · <s>Nedlagt</s>' : '') + '</div>' +
          '<div>' + esc(s.k) + (s.b ? ' · ' + esc(s.b) : '') + '</div>' +
          (s.r ? '<div>Anmeldt: <strong>' + esc(s.r) + '</strong></div>' : '');
        m.bindPopup(html);
        bounds.push([s.lat, s.lng]);
      });
      if (bounds.length > 1) map.fitBounds(bounds, { padding: [30, 30], maxZoom: 15 });
      else if (bounds.length === 1) map.setView(bounds[0], 15);
    })
    .catch(function () { /* kartet fungerer fortsatt uten pins */ });
})();
