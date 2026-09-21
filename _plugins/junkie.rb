# frozen_string_literal: true

# Junkie – avledet data og genererte sider.
#
# Kjøres etter at Jekyll har lest alle filer (post_read) og gjør følgende:
#   * Kobler anmeldelser (_anmeldelser) til steder (_steder) via `venue`.
#   * Regner ut steds-score (høyeste rett-score, evt. score_override),
#     beste rett, retter med revisit-tidslinje og tags.
#   * Lager ankerpunkt for hver anmeldelse: <rett-slug>-<YYYY-MM>.
#   * Skjuler steder uten publiserte anmeldelser (i produksjon).
#   * Løser opp kuraterte lister (referanser til anmeldelsesfiler).
#   * Bygger forsidefeed (maks én anmeldelse per sted).
#   * Genererer /kategori/:slug/, /tag/:slug/ og /bydel/:slug/.
#
# I utviklingsmodus (JEKYLL_ENV != production) vises utkast med tydelig
# merking, slik at du kan se anmeldelsen mens du skriver den.

module Junkie
  MONTHS = %w[januar februar mars april mai juni juli august september oktober november desember].freeze
  SCORE_LABELS = {
    0 => "Anmeldt, ikke anbefalt",
    1 => "God – verdt et besøk",
    2 => "Veldig god – definitivt verdt en tur",
    3 => "Eksepsjonell – dette MÅ du prøve",
  }.freeze

  module_function

  def production?
    Jekyll.env == "production"
  end

  def slugify(str)
    s = str.to_s.dup
    s = s.gsub("æ", "ae").gsub("Æ", "ae").gsub("ø", "o").gsub("Ø", "o").gsub("å", "a").gsub("Å", "a")
    Jekyll::Utils.slugify(s, mode: "latin")
  end

  # "2026-03" | Date | Time -> "2026-03"
  def month_key(val)
    case val
    when Date, Time then val.strftime("%Y-%m")
    when nil then nil
    else
      s = val.to_s.strip
      s =~ /\A(\d{4})-(\d{1,2})/ ? format("%04d-%02d", Regexp.last_match(1).to_i, Regexp.last_match(2).to_i) : s
    end
  end

  # "2026-03" -> "mars 2026"
  def month_label(key)
    return "" if key.nil?
    y, m = key.to_s.split("-").map(&:to_i)
    return key.to_s unless y && m && (1..12).cover?(m)
    "#{MONTHS[m - 1]} #{y}"
  end

  def clamp_score(val)
    return nil if val.nil? || val.to_s.strip.empty?
    val.to_i.clamp(0, 3)
  end

  # Leser bredde/høyde fra JPEG-, PNG-, GIF- og WebP-headere. Ingen bildebehandling.
  def image_dimensions(path)
    return nil unless File.file?(path)
    File.open(path, "rb") do |f|
      head = f.read(32) || ""
      if head.start_with?("\x89PNG".b)
        return head[16, 8].unpack("N2")
      elsif head.start_with?("GIF8".b)
        return head[6, 4].unpack("v2")
      elsif head.start_with?("RIFF".b) && head[8, 4] == "WEBP".b
        chunk = head[12, 4]
        f.seek(12)
        data = f.read(30) || ""
        case chunk
        when "VP8 ".b then return data[14, 4].unpack("v2").map { |x| x & 0x3fff }
        when "VP8L".b then b = data[9, 4].unpack("C4"); return [(b[0] | (b[1] & 0x3f) << 8) + 1, ((b[1] >> 6) | b[2] << 2 | (b[3] & 0xf) << 10) + 1]
        when "VP8X".b then return [1 + (data[12, 3].unpack1("V") & 0xffffff), 1 + (data[15, 3].unpack1("V") & 0xffffff)] rescue nil
        end
      elsif head.start_with?("\xFF\xD8".b)
        f.seek(2)
        loop do
          marker = f.read(2)
          break if marker.nil? || marker.bytesize < 2 || marker.getbyte(0) != 0xFF
          m = marker.getbyte(1)
          next if m == 0xFF
          len = f.read(2)&.unpack1("n") or break
          if [0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF].include?(m)
            seg = f.read(5)
            return seg[3, 2].unpack1("n"), seg[1, 2].unpack1("n") if seg && seg.bytesize == 5
            break
          end
          f.seek(len - 2, IO::SEEK_CUR)
        end
      end
    end
    nil
  rescue StandardError
    nil
  end

  # Normaliserer et bilde (streng eller hash) og fyller inn bredde/høyde. Returnerer nil ved manglende fil.
  def image_info(site, img, fallback_alt, problems, owner)
    img = { "src" => img } if img.is_a?(String)
    return nil unless img.is_a?(Hash) && !img["src"].to_s.strip.empty?
    src = img["src"].to_s.strip
    info = img.merge("src" => src, "alt" => (img["alt"].to_s.empty? ? fallback_alt.to_s : img["alt"].to_s))
    unless src.start_with?("http")
      path = File.join(site.source, src.sub(%r{\A/}, ""))
      dims = image_dimensions(path)
      if dims
        info["width"], info["height"] = dims
      elsif File.file?(path)
        problems[:warnings] << "#{owner}: fant ikke bildestørrelse for #{src}"
      else
        problems[:errors] << "#{owner}: bildet #{src} finnes ikke i repoet"
      end
    end
    info
  end

  def excerpt(markdown, length = 180)
    text = markdown.to_s
      .gsub(/!\[[^\]]*\]\([^)]*\)/, "")        # bilder
      .gsub(/\[([^\]]*)\]\([^)]*\)/, '\1')     # lenker
      .gsub(/[*_`#>]+/, "")
      .gsub(/\s+/, " ")
      .strip
    return text if text.length <= length
    cut = text[0, length]
    cut = cut[0, cut.rindex(" ") || length]
    "#{cut}…"
  end
end

# ---------------------------------------------------------------------------
# Liquid-filtre
# ---------------------------------------------------------------------------
module Junkie
  module Filters
    def junkie_slugify(str)
      Junkie.slugify(str)
    end

    def month_label(key)
      Junkie.month_label(Junkie.month_key(key))
    end

    def score_label(score)
      Junkie::SCORE_LABELS[score.to_i] || ""
    end

    def junkie_excerpt(text, length = 180)
      Junkie.excerpt(text, length.to_i)
    end
  end
end
Liquid::Template.register_filter(Junkie::Filters)

# ---------------------------------------------------------------------------
# Avledet data
# ---------------------------------------------------------------------------
Jekyll::Hooks.register :site, :post_read do |site|
  show_drafts = !Junkie.production?
  venues  = site.collections["steder"]&.docs || []
  reviews = site.collections["anmeldelser"]&.docs || []
  lists   = site.collections["lister"]&.docs || []

  default_image = site.config["default_image"]
  problems = { errors: [], warnings: [] }
  site.data["problems"] = problems

  # Hash av CSS/JS-kildene for cache-busting (?v=...)
  require "digest"
  asset_files = Dir[File.join(site.source, "_sass", "**", "*.scss")] +
                Dir[File.join(site.source, "assets", "css", "*.scss")] +
                Dir[File.join(site.source, "assets", "js", "*.js")]
  site.data["asset_hash"] = Digest::MD5.hexdigest(asset_files.sort.map { |f| File.read(f, encoding: "UTF-8") }.join)[0, 8]

  kategorier = (site.data["kategorier"] || []).each_with_object({}) { |k, h| h[k["slug"]] = k }
  bydeler    = (site.data["bydeler"] || []).each_with_object({}) { |b, h| h[b["slug"]] = b }

  venue_by_key = venues.each_with_object({}) { |v, h| h[v.basename_without_ext] = v }
  tags_index   = Hash.new { |h, k| h[k] = { "slug" => k, "name" => nil, "reviews" => [] } }

  # --- anmeldelser -------------------------------------------------------
  reviews.each do |r|
    r.data["key"]     = r.basename_without_ext
    r.data["status"]  = (r.data["status"] || "published").to_s
    unless %w[draft published archived].include?(r.data["status"])
      problems[:errors] << "#{r.relative_path}: ukjent status '#{r.data['status']}' (draft | published | archived)"
    end
    raw_score = r.data["score"]
    if raw_score.nil? || raw_score.to_s.strip.empty? || raw_score.to_s !~ /\A[0-3]\z/
      problems[:errors] << "#{r.relative_path}: score må være 0, 1, 2 eller 3 (er '#{raw_score}')"
    end
    problems[:errors] << "#{r.relative_path}: mangler title (rettens navn)" if r.data["title"].to_s.strip.empty?
    problems[:errors] << "#{r.relative_path}: visited må være YYYY-MM (er '#{r.data['visited']}')" unless Junkie.month_key(r.data["visited"]).to_s =~ /\A\d{4}-\d{2}\z/
    r.data["score"]   = Junkie.clamp_score(r.data["score"]) || 0
    r.data["visited"] = Junkie.month_key(r.data["visited"])
    r.data["visited_label"] = Junkie.month_label(r.data["visited"])
    r.data["dish_slug"] = Junkie.slugify(r.data["title"])
    r.data["anchor"]  = r.data["anchor"].to_s.empty? ? "#{r.data['dish_slug']}-#{r.data['visited']}" : r.data["anchor"].to_s
    r.data["excerpt"] = Junkie.excerpt(r.content)
    r.data["images"]  = Array(r.data["images"]).map { |i| Junkie.image_info(site, i, r.data["title"], problems, r.relative_path) }.compact
    r.data["image"]   = r.data["images"].first && r.data["images"].first["src"]
    r.data["tags"]    = Array(r.data["tags"]).map(&:to_s).map(&:strip).reject(&:empty?)
    r.data["tag_slugs"] = r.data["tags"].map { |t| Junkie.slugify(t) }
    r.data["date"] ||= Time.now
    r.data["public"]  = r.data["status"] == "published" || (show_drafts && r.data["status"] == "draft")
    r.data["draft"]   = r.data["status"] == "draft"

    venue = venue_by_key[r.data["venue"].to_s]
    if venue.nil?
      problems[:errors] << "#{r.relative_path}: peker på ukjent sted '#{r.data['venue']}' (finnes ikke i _steder/)"
      r.data["public"] = false
      next
    end
    r.data["venue_doc"] = venue
    r.data["venue_title"] = venue.data["title"]
    r.data["lenke"] = "#{venue.url}##{r.data['anchor']}"
  end

  # --- steder ------------------------------------------------------------
  venues.each do |v|
    key = v.basename_without_ext
    v.data["key"] = key
    v.data["status"] = (v.data["status"] || "open").to_s
    v.data["closed"] = v.data["status"] == "closed"
    v.data["closed_label"] = Junkie.month_label(Junkie.month_key(v.data["closed_at"]))
    v.data["categories"] = Array(v.data["categories"]).map { |c| Junkie.slugify(c) }
    problems[:warnings] << "#{v.relative_path}: mangler categories" if v.data["categories"].empty?
    (v.data["categories"] - kategorier.keys).each { |c| problems[:warnings] << "#{v.relative_path}: kategorien '#{c}' finnes ikke i _data/kategorier.yml" }
    v.data["cover"] = Junkie.image_info(site, v.data["cover_image"], v.data["title"], problems, v.relative_path)
    v.data["category_data"] = v.data["categories"].map { |c| kategorier[c] || { "slug" => c, "name" => c.capitalize } }
    v.data["summary"] = v.content.to_s.strip

    # Lokasjoner: `locations:` i front matter, ellers én lokasjon fra stedets egne felter
    locs = Array(v.data["locations"]).select { |l| l.is_a?(Hash) }
    if locs.empty?
      locs = [{ "address" => v.data["address"], "lat" => v.data["lat"], "lng" => v.data["lng"],
                "google_maps_url" => v.data["google_maps_url"], "bydel" => v.data["bydel"], "status" => v.data["status"] }]
    end
    locs = locs.map do |l|
      l = l.dup
      l["name"] = l["name"].to_s.strip
      bs = l["bydel"].to_s.empty? ? nil : Junkie.slugify(l["bydel"])
      l["bydel_slug"] = bs
      l["bydel_data"] = bs && (bydeler[bs] || { "slug" => bs, "name" => l["bydel"].to_s })
      l["has_coords"] = !l["lat"].nil? && !l["lng"].nil?
      l["closed"] = l["status"].to_s == "closed" || v.data["closed"]
      l["closed_label"] = Junkie.month_label(Junkie.month_key(l["closed_at"]))
      l
    end
    v.data["locations"] = locs
    v.data["multi"] = locs.size > 1
    v.data["has_coords"] = locs.any? { |l| l["has_coords"] }
    v.data["open_locations"] = locs.reject { |l| l["closed"] }
    # Alle lokasjoner nedlagt = stedet nedlagt
    v.data["closed"] = true if v.data["open_locations"].empty? && !locs.empty?
    first = locs.first
    v.data["address"] ||= first["address"]
    v.data["lat"] ||= first["lat"]
    v.data["lng"] ||= first["lng"]
    v.data["bydel_list"] = locs.map { |l| l["bydel_data"] }.compact.uniq { |b| b["slug"] }
    v.data["bydel_slugs"] = v.data["bydel_list"].map { |b| b["slug"] }
    v.data["bydel_slug"] = v.data["bydel_slugs"].first
    v.data["bydel_data"] = v.data["bydel_list"].first
    v.data["bydel_label"] = v.data["bydel_list"].map { |b| b["name"] }.join(", ")
    v.data["map_points"] = locs.select { |l| l["has_coords"] }.map do |l|
      { "lat" => l["lat"], "lng" => l["lng"], "name" => l["name"], "closed" => l["closed"] }
    end

    pub = reviews.select { |r| r.data["venue_doc"].equal?(v) && r.data["public"] }
    pub = pub.sort_by { |r| [r.data["visited"].to_s, r.data["date"].to_s] }.reverse
    v.data["reviews"] = pub
    v.data["review_count"] = pub.size
    pub.group_by { |r| r.data["anchor"] }.each do |anchor, rs|
      next if rs.size < 2
      problems[:errors] << "#{v.relative_path}: #{rs.size} anmeldelser får samme anker '##{anchor}' (#{rs.map(&:relative_path).join(', ')}) – sett anchor: i en av dem"
    end
    v.data["visible"] = !pub.empty?

    auto = pub.map { |r| r.data["score"] }.max
    v.data["auto_score"] = auto
    override = Junkie.clamp_score(v.data["score_override"])
    v.data["score"] = override || auto || 0
    v.data["score_label"] = Junkie::SCORE_LABELS[v.data["score"]]
    v.data["featured_review"] = pub.max_by { |r| [r.data["score"], r.data["visited"].to_s] }

    # Retter: grupper etter tittel, nyeste besøk først
    dishes = pub.group_by { |r| r.data["dish_slug"] }.map do |slug, rs|
      {
        "slug" => slug,
        "title" => rs.first.data["title"],
        "reviews" => rs,
        "latest" => rs.first,
        "score" => rs.first.data["score"],
        "revisits" => rs.size - 1,
      }
    end
    v.data["dishes"] = dishes.sort_by { |d| [-d["score"], -d["latest"].data["visited"].to_s.delete("-").to_i] }

    v.data["tags"] = pub.flat_map { |r| r.data["tags"] }.uniq
    v.data["tag_slugs"] = pub.flat_map { |r| r.data["tag_slugs"] }.uniq
    v.data["image"] = v.data["cover"]&.[]("src") || v.data["featured_review"]&.data&.[]("image") || default_image
    v.data["card_image"] = v.data["cover"] || v.data["featured_review"]&.data&.[]("images")&.first
    v.data["latest_date"] = pub.map { |r| r.data["date"] }.max
    v.data["date"] ||= v.data["latest_date"]
    v.data["description"] ||= if v.data["summary"].empty?
      fr = v.data["featured_review"]
      fr ? "#{fr.data['title']} – #{Junkie.excerpt(fr.content, 150)}" : nil
    else
      Junkie.excerpt(v.data["summary"], 160)
    end

    pub.each do |r|
      r.data["tags"].each_with_index do |t, i|
        entry = tags_index[r.data["tag_slugs"][i]]
        entry["name"] ||= t
        problems[:warnings] << "#{r.relative_path}: tag '#{t}' er skrevet '#{entry['name']}' andre steder – samme side, men første stavemåte vises" if entry["name"] != t
        entry["reviews"] << r
      end
    end
  end

  # Skjul steder uten publiserte anmeldelser
  hidden = venues.reject { |v| v.data["visible"] }
  reviews.select { |r| r.data["status"] == "draft" }.each do |r|
    Jekyll.logger.info "Junkie info:", "#{r.relative_path} er utkast (status: draft) – sett status: published når den er klar"
  end
  hidden.each { |v| Jekyll.logger.info "Junkie info:", "#{v.relative_path} har ingen publisert anmeldelse og vises ikke#{show_drafts ? "" : " (utkast teller ikke i produksjon)"}" }
  site.collections["steder"].docs.reject! { |v| !v.data["visible"] } if site.collections["steder"]
  visible_venues = site.collections["steder"]&.docs || []

  # --- kuraterte lister --------------------------------------------------
  lists.each do |l|
    l.data["status"] = (l.data["status"] || "published").to_s
    l.data["public"] = l.data["status"] == "published" || (show_drafts && l.data["status"] == "draft")
    l.data["draft"] = l.data["status"] == "draft"
    l.data["intro"] = l.content.to_s.strip
    l.data["description"] ||= Junkie.excerpt(l.data["intro"], 160)
    items = Array(l.data["items"]).map do |item|
      item = { "review" => item } if item.is_a?(String)
      review = reviews.find { |r| r.data["key"] == item["review"].to_s }
      if review.nil? || review.data["venue_doc"].nil?
        problems[:errors] << "#{l.relative_path}: peker på ukjent anmeldelse '#{item['review']}' (filnavn i _anmeldelser/ uten .md)"
        next
      end
      next if review.data["status"] == "draft" && !show_drafts
      {
        "review" => review,
        "venue" => review.data["venue_doc"],
        "note" => item["note"].to_s,
        "archived" => review.data["status"] == "archived",
      }
    end.compact
    l.data["items"] = items
    l.data["card_image"] = items.map { |i| i["review"].data["images"].first || i["venue"].data["cover"] }.compact.first
    l.data["image"] = l.data["card_image"]&.[]("src") || default_image
  end
  site.collections["lister"].docs.reject! { |l| !l.data["public"] } if site.collections["lister"]
  # Uten lister: hold /lister/ ute av menyen (header.html) og sitemap
  if site.collections["lister"].nil? || site.collections["lister"].docs.empty?
    site.pages.find { |p| p.url == "/lister/" }&.data&.[]=("sitemap", false)
  end

  # --- feed: nyeste publiserte anmeldelser, maks én per sted --------------
  seen = {}
  feed = reviews
    .select { |r| r.data["public"] && r.data["venue_doc"] }
    .sort_by { |r| r.data["date"] }.reverse
    .select { |r| k = r.data["venue_doc"].data["key"]; seen[k] ? false : (seen[k] = true) }

  # --- indekser for genererte sider ---------------------------------------
  tag_list = tags_index.values.map do |t|
    t["venues"] = t["reviews"].map { |r| r.data["venue_doc"] }.uniq
    t["count"] = t["venues"].size
    t
  end.sort_by { |t| [-t["count"], t["slug"]] }

  kat_list = (site.data["kategorier"] || []).map do |k|
    k = k.dup
    k["venues"] = visible_venues.select { |v| v.data["categories"].include?(k["slug"]) }
    k["count"] = k["venues"].size
    k
  end

  used_bydeler = visible_venues.flat_map { |v| v.data["bydel_list"] }.uniq { |b| b["slug"] }
  bydel_list = used_bydeler.map do |b|
    b = b.dup
    b["venues"] = visible_venues.select { |v| v.data["bydel_slugs"].include?(b["slug"]) }
    b["count"] = b["venues"].size
    b
  end.sort_by { |b| b["name"].to_s }

  per_page = (site.config["feed_per_page"] || 24).to_i
  feed_pages = feed.each_slice(per_page).to_a
  feed_pages = [[]] if feed_pages.empty?

  # Rapport: advarsler alltid, feil stopper produksjonsbygg
  problems[:warnings].uniq.each { |w| Jekyll.logger.warn "Junkie advarsel:", w }
  problems[:errors].uniq.each { |e| Jekyll.logger.error "Junkie feil:", e }
  Jekyll.logger.info "Junkie status:", "#{problems[:errors].uniq.size} feil, #{problems[:warnings].uniq.size} advarsler, #{hidden.size} skjulte steder"
  unless problems[:errors].empty?
    raise Jekyll::Errors::FatalException, "Junkie: #{problems[:errors].uniq.size} feil i innholdet (se over)" if Junkie.production?
  end

  site.data["junkie"] = {
    "feed" => feed,
    "feed_pages" => feed_pages,
    "per_page" => per_page,
    "reviews" => reviews.select { |r| r.data["public"] && r.data["venue_doc"] }.sort_by { |r| r.data["date"] }.reverse,
    "venues" => visible_venues.sort_by { |v| [-v.data["score"], v.data["title"].to_s.downcase] },
    "tags" => tag_list,
    "kategorier" => kat_list,
    "bydeler" => bydel_list,
    "show_drafts" => show_drafts,
  }
end

# ---------------------------------------------------------------------------
# Genererte sider: /kategori/:slug/, /tag/:slug/, /bydel/:slug/
# ---------------------------------------------------------------------------
module Junkie
  class TermPage < Jekyll::PageWithoutAFile
    def initialize(site, dir, layout, term, extra = {})
      super(site, site.source, dir, "index.html")
      @data = {
        "layout" => layout,
        "title" => term["name"],
        "term" => term,
        "venues" => term["venues"],
        "sitemap" => true,
      }.merge(extra)
    end
  end

  class TermGenerator < Jekyll::Generator
    safe true
    priority :low

    def generate(site)
      j = site.data["junkie"] or return

      j["kategorier"].each do |k|
        site.pages << TermPage.new(site, "kategori/#{k['slug']}", "kategori", k,
          "description" => k["description"] || "Steder i Oslo anmeldt av Junkie i kategorien #{k['name'].to_s.downcase}.")
      end

      j["tags"].each do |t|
        site.pages << TermPage.new(site, "tag/#{t['slug']}", "tag", t,
          "title" => "##{t['name']}",
          "description" => "Retter tagget «#{t['name']}» anmeldt av Junkie.")
      end

      j["bydeler"].each do |b|
        site.pages << TermPage.new(site, "bydel/#{b['slug']}", "bydel", b,
          "description" => "Gatemat i #{b['name']} anmeldt av Junkie.")
      end

      # Feed-sider: /side/2/, /side/3/ ... (side 1 er forsiden)
      j["feed_pages"].each_with_index do |slice, i|
        next if i.zero?
        page = Jekyll::PageWithoutAFile.new(site, site.source, "side/#{i + 1}", "index.html")
        page.data = {
          "layout" => "feed",
          "title" => "Siste anmeldelser, side #{i + 1}",
          "description" => "Junkies anmeldelser, side #{i + 1} av #{j['feed_pages'].size}.",
          "feed_slice" => slice,
          "page_num" => i + 1,
          "page_total" => j["feed_pages"].size,
          "sitemap" => true,
        }
        site.pages << page
      end
    end
  end
end

# ---------------------------------------------------------------------------
# Markdown for maskiner: /steder/:slug.md, /tag/:slug.md, /bydel/:slug.md,
# /lister/:slug.md, /om.md, /llms.txt og /llms-full.txt
# ---------------------------------------------------------------------------
module Junkie
  STARS = { 0 => "☆☆☆", 1 => "★☆☆", 2 => "★★☆", 3 => "★★★" }.freeze

  # Rå tekstfil som ikke går gjennom markdown-konvertering eller Liquid.
  class RawPage < Jekyll::PageWithoutAFile
    def initialize(site, permalink, content, extra = {})
      super(site, site.source, "", "raw.txt")
      @content = content
      @data = { "permalink" => permalink, "layout" => nil, "sitemap" => false }.merge(extra)
    end

    def render_with_liquid?
      false
    end
  end

  module Markdown
    module_function

    def abs(site, path)
      "#{site.config['url']}#{site.config['baseurl']}#{path}"
    end

    def score_line(score)
      "#{STARS[score]} #{score}/3 – #{SCORE_LABELS[score]}"
    end

    def venue(site, v)
      d = v.data
      out = +"# #{d['title']}\n\n"
      out << "- Score: #{score_line(d['score'])}\n"
      out << "- Kategorier: #{d['category_data'].map { |k| k['name'] }.join(', ')}\n" unless d["category_data"].empty?
      out << "- Bydel: #{d['bydel_label']}\n" unless d["bydel_label"].to_s.empty?
      d["locations"].each do |l|
        next if l["address"].to_s.empty? && l["name"].to_s.empty?
        label = l["name"].to_s.empty? ? "Adresse" : "Adresse (#{l['name']})"
        line = "- #{label}: #{l['address']}"
        line << " – nedlagt#{l['closed_label'].to_s.empty? ? '' : " #{l['closed_label']}"}" if l["closed"] && !d["closed"]
        line << " – [Google Maps](#{l['google_maps_url']})" if l["google_maps_url"]
        out << line << "\n"
      end
      out << "- Status: Nedlagt#{d['closed_label'].to_s.empty? ? '' : " (#{d['closed_label']})"}\n" if d["closed"]
      out << "- Nettside: #{abs(site, v.url)}\n"
      out << "\n#{d['summary']}\n" unless d["summary"].to_s.empty?
      out << "\n## Anmeldte retter\n"
      d["dishes"].each do |dish|
        dish["reviews"].each_with_index do |r, i|
          rd = r.data
          if i.zero?
            out << "\n### #{dish['title']} – #{STARS[rd['score']]} #{rd['score']}/3\n\n"
          else
            out << "\n#### Tidligere besøk: #{rd['visited_label']} – #{STARS[rd['score']]} #{rd['score']}/3\n\n"
          end
          meta = ["Besøkt #{rd['visited_label']}"]
          meta << "Tags: #{rd['tags'].join(', ')}" unless rd["tags"].empty?
          out << "*#{meta.join('. ')}.*\n\n"
          out << r.content.to_s.strip << "\n"
        end
      end
      out
    end

    def list(site, l)
      d = l.data
      out = +"# #{d['title']}\n\n"
      out << "#{d['intro']}\n\n" unless d["intro"].to_s.empty?
      out << "- Nettside: #{abs(site, l.url)}\n\n"
      d["items"].each_with_index do |item, i|
        v = item["venue"]; r = item["review"]
        out << "#{i + 1}. **#{v.data['title']}** – #{r.data['title']} #{STARS[r.data['score']]}"
        out << " (arkivert anmeldelse)" if item["archived"]
        out << "\n   #{item['note']}" unless item["note"].to_s.empty?
        out << "\n   #{r.data['excerpt']}\n   Mer: #{abs(site, "#{v.url.chomp('/')}.md")}\n"
      end
      out
    end

    def venue_row(site, v)
      d = v.data
      fr = d["featured_review"]
      s = "- [#{d['title']}](#{abs(site, "#{v.url.chomp('/')}.md")}): #{STARS[d['score']]}"
      s << ", #{d['category_data'].map { |k| k['name'] }.join('/')}" unless d["category_data"].empty?
      s << ", #{d['bydel_label']}" unless d["bydel_label"].to_s.empty?
      s << ", nedlagt" if d["closed"]
      s << ". Anmeldt: #{fr.data['title']}" if fr
      s << "\n"
    end

    def tag(site, t)
      out = +"# ##{t['name']}\n\nRetter tagget «#{t['name']}» hos Junkie.\n\n"
      t["reviews"].sort_by { |r| -r.data["score"] }.each do |r|
        v = r.data["venue_doc"]
        out << "- **#{v.data['title']}** – #{r.data['title']} #{STARS[r.data['score']]}: #{r.data['excerpt']} ([mer](#{abs(site, "#{v.url.chomp('/')}.md")}))\n"
      end
      out
    end

    def bydel(site, b)
      out = +"# #{b['name']}\n\nGatemat i #{b['name']} anmeldt av Junkie.\n\n"
      b["venues"].sort_by { |v| -v.data["score"] }.each { |v| out << venue_row(site, v) }
      out
    end

    def intro_text(site)
      path = File.join(site.source, "_includes", "forside-intro.md")
      File.exist?(path) ? File.read(path, encoding: "UTF-8").strip : site.config["description"].to_s
    end

    def scale_text
      <<~MD
        ## Skalaen

        Junkie anmelder enkeltretter, ikke steder. Hver rett får 0–3 stjerner:

        - ★★★ 3/3 – Eksepsjonell. Dette MÅ du prøve.
        - ★★☆ 2/3 – Veldig god. Definitivt verdt en tur.
        - ★☆☆ 1/3 – God. Verdt et besøk.
        - ☆☆☆ 0/3 – Anmeldt, men ikke anbefalt.

        Et sted får automatisk scoren til sin beste rett. Samme rett kan anmeldes på nytt senere; alle besøk står oppført. Ingen betalte omtaler.
      MD
    end

    def om(site)
      "# Om Junkie\n\n#{intro_text(site)}\n\n#{scale_text}"
    end

    def llms(site, j)
      out = +"# #{site.config['title']}\n\n> #{site.config['description']}\n\n"
      out << "#{intro_text(site)}\n\n"
      out << scale_text << "\n"
      out << "Alle sider finnes som markdown: bytt ut avsluttende `/` med `.md`. Hele guiden i én fil: #{abs(site, '/llms-full.txt')}\n\n"
      out << "## Steder\n\n"
      j["venues"].each { |v| out << venue_row(site, v) }
      lists = site.collections["lister"]&.docs || []
      unless lists.empty?
        out << "\n## Lister\n\n"
        lists.each { |l| out << "- [#{l.data['title']}](#{abs(site, "#{l.url.chomp('/')}.md")}): #{l.data['description']}\n" }
      end
      unless j["bydeler"].empty?
        out << "\n## Bydeler\n\n"
        j["bydeler"].each { |b| out << "- [#{b['name']}](#{abs(site, "/bydel/#{b['slug']}.md")}): #{b['count']} #{b['count'] == 1 ? 'sted' : 'steder'}\n" }
      end
      unless j["tags"].empty?
        out << "\n## Tags\n\n"
        j["tags"].each { |t| out << "- [##{t['name']}](#{abs(site, "/tag/#{t['slug']}.md")}): #{t['reviews'].size} #{t['reviews'].size == 1 ? 'rett' : 'retter'}\n" }
      end
      out << "\n## Om\n\n- [Om Junkie](#{abs(site, '/om.md')})\n"
      out
    end

    def llms_full(site, j)
      out = +"# #{site.config['title']} – hele guiden\n\n> #{site.config['description']}\n\n"
      out << "#{intro_text(site)}\n\n" << scale_text << "\n---\n\n"
      j["venues"].each { |v| out << venue(site, v) << "\n---\n\n" }
      (site.collections["lister"]&.docs || []).each { |l| out << list(site, l) << "\n---\n\n" }
      out
    end
  end

  class MarkdownGenerator < Jekyll::Generator
    safe true
    priority :lowest

    def generate(site)
      j = site.data["junkie"] or return
      add = ->(permalink, content) { site.pages << RawPage.new(site, permalink, content) }

      (site.collections["steder"]&.docs || []).each do |v|
        v.data["md_url"] = "#{v.url.chomp('/')}.md"
        add.call(v.data["md_url"], Markdown.venue(site, v))
      end
      (site.collections["lister"]&.docs || []).each do |l|
        l.data["md_url"] = "#{l.url.chomp('/')}.md"
        add.call(l.data["md_url"], Markdown.list(site, l))
      end
      j["tags"].each do |t|
        add.call("/tag/#{t['slug']}.md", Markdown.tag(site, t))
      end
      j["bydeler"].each do |b|
        add.call("/bydel/#{b['slug']}.md", Markdown.bydel(site, b))
      end
      site.pages.each do |p|
        next unless p.data["term"]
        p.data["md_url"] = "#{p.url.chomp('/')}.md" if p.url.start_with?("/tag/", "/bydel/")
      end
      site.pages.find { |p| p.url == "/om/" }&.data&.[]=("md_url", "/om.md")
      add.call("/om.md", Markdown.om(site))
      add.call("/llms.txt", Markdown.llms(site, j))
      add.call("/llms-full.txt", Markdown.llms_full(site, j))
    end
  end
end
