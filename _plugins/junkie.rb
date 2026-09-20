# frozen_string_literal: true

# Junkie – avledet data og genererte sider.
#
# Kjøres etter at Jekyll har lest alle filer (post_read) og gjør følgende:
#   * Kobler anmeldelser (_anmeldelser) til steder (_steder) via `venue`.
#   * Regner ut steds-score (høyeste rett-score, evt. score_override),
#     anbefalt rett, retter med revisit-tidslinje og tags.
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
  kategorier = (site.data["kategorier"] || []).each_with_object({}) { |k, h| h[k["slug"]] = k }
  bydeler    = (site.data["bydeler"] || []).each_with_object({}) { |b, h| h[b["slug"]] = b }

  venue_by_key = venues.each_with_object({}) { |v, h| h[v.basename_without_ext] = v }
  tags_index   = Hash.new { |h, k| h[k] = { "slug" => k, "name" => nil, "reviews" => [] } }

  # --- anmeldelser -------------------------------------------------------
  reviews.each do |r|
    r.data["key"]     = r.basename_without_ext
    r.data["status"]  = (r.data["status"] || "draft").to_s
    r.data["score"]   = Junkie.clamp_score(r.data["score"]) || 0
    r.data["visited"] = Junkie.month_key(r.data["visited"])
    r.data["visited_label"] = Junkie.month_label(r.data["visited"])
    r.data["dish_slug"] = Junkie.slugify(r.data["title"])
    r.data["anchor"]  = r.data["anchor"].to_s.empty? ? "#{r.data['dish_slug']}-#{r.data['visited']}" : r.data["anchor"].to_s
    r.data["excerpt"] = Junkie.excerpt(r.content)
    r.data["images"]  = Array(r.data["images"]).map { |i| i.is_a?(String) ? { "src" => i, "alt" => "" } : i }
    r.data["image"]   = r.data["images"].first && r.data["images"].first["src"]
    r.data["tags"]    = Array(r.data["tags"]).map(&:to_s).map(&:strip).reject(&:empty?)
    r.data["tag_slugs"] = r.data["tags"].map { |t| Junkie.slugify(t) }
    r.data["date"] ||= Time.now
    r.data["public"]  = r.data["status"] == "published" || (show_drafts && r.data["status"] == "draft")
    r.data["draft"]   = r.data["status"] == "draft"

    venue = venue_by_key[r.data["venue"].to_s]
    if venue.nil?
      Jekyll.logger.warn "Junkie:", "Anmeldelse #{r.relative_path} peker på ukjent sted '#{r.data['venue']}'"
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
    v.data["category_data"] = v.data["categories"].map { |c| kategorier[c] || { "slug" => c, "name" => c.capitalize } }
    bslug = v.data["bydel"].to_s.empty? ? nil : Junkie.slugify(v.data["bydel"])
    v.data["bydel_slug"] = bslug
    v.data["bydel_data"] = bslug && (bydeler[bslug] || { "slug" => bslug, "name" => v.data["bydel"].to_s })
    v.data["summary"] = v.content.to_s.strip
    v.data["has_coords"] = !v.data["lat"].nil? && !v.data["lng"].nil?

    pub = reviews.select { |r| r.data["venue_doc"].equal?(v) && r.data["public"] }
    pub = pub.sort_by { |r| [r.data["visited"].to_s, r.data["date"].to_s] }.reverse
    v.data["reviews"] = pub
    v.data["review_count"] = pub.size
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
    v.data["image"] = v.data["cover_image"] || v.data["featured_review"]&.data&.[]("image") || default_image
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
        entry["reviews"] << r
      end
    end
  end

  # Skjul steder uten publiserte anmeldelser
  hidden = venues.reject { |v| v.data["visible"] }
  hidden.each { |v| Jekyll.logger.info "Junkie:", "Skjuler #{v.relative_path} (ingen publiserte anmeldelser)" }
  site.collections["steder"].docs.reject! { |v| !v.data["visible"] } if site.collections["steder"]
  visible_venues = site.collections["steder"]&.docs || []

  # --- kuraterte lister --------------------------------------------------
  lists.each do |l|
    l.data["status"] = (l.data["status"] || "draft").to_s
    l.data["public"] = l.data["status"] == "published" || (show_drafts && l.data["status"] == "draft")
    l.data["draft"] = l.data["status"] == "draft"
    l.data["intro"] = l.content.to_s.strip
    l.data["description"] ||= Junkie.excerpt(l.data["intro"], 160)
    items = Array(l.data["items"]).map do |item|
      item = { "review" => item } if item.is_a?(String)
      review = reviews.find { |r| r.data["key"] == item["review"].to_s }
      if review.nil? || review.data["venue_doc"].nil?
        Jekyll.logger.warn "Junkie:", "Liste #{l.relative_path} peker på ukjent anmeldelse '#{item['review']}'"
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
    l.data["image"] = items.map { |i| i["review"].data["image"] || i["venue"].data["cover_image"] }.compact.first || default_image
  end
  site.collections["lister"].docs.reject! { |l| !l.data["public"] } if site.collections["lister"]

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

  used_bydeler = visible_venues.map { |v| v.data["bydel_data"] }.compact.uniq { |b| b["slug"] }
  bydel_list = used_bydeler.map do |b|
    b = b.dup
    b["venues"] = visible_venues.select { |v| v.data["bydel_slug"] == b["slug"] }
    b["count"] = b["venues"].size
    b
  end.sort_by { |b| b["name"].to_s }

  site.data["junkie"] = {
    "feed" => feed,
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
    end
  end
end
