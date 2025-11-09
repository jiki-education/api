class Level::Search
  include Mandate

  DEFAULT_PAGE = 1
  DEFAULT_PER = 24

  def self.default_per
    DEFAULT_PER
  end

  def initialize(title: nil, slug: nil, page: nil, per: nil)
    @title = title
    @slug = slug
    @page = page.present? && page.to_i.positive? ? page.to_i : DEFAULT_PAGE
    @per = per.present? && per.to_i.positive? ? per.to_i : self.class.default_per
  end

  def call
    @levels = Level.all

    filter_title!
    filter_slug!

    @levels.page(page).per(per)
  end

  private
  attr_reader :title, :slug, :page, :per

  def filter_title!
    return if title.blank?

    @levels = @levels.where("title LIKE ?", "%#{Level.sanitize_sql_like(title)}%")
  end

  def filter_slug!
    return if slug.blank?

    @levels = @levels.where("slug LIKE ?", "%#{Level.sanitize_sql_like(slug)}%")
  end
end
