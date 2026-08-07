class Level::Search
  include Mandate

  DEFAULT_PAGE = 1
  DEFAULT_PER = 24

  def self.default_per
    DEFAULT_PER
  end

  def initialize(course: nil, slug: nil, page: nil, per: nil)
    @course = course
    @slug = slug
    @page = page.present? && page.to_i.positive? ? page.to_i : DEFAULT_PAGE
    @per = per.present? && per.to_i.positive? ? per.to_i : self.class.default_per
  end

  def call
    @levels = course ? course.levels : Level.all

    filter_slug!

    @levels.page(page).per(per)
  end

  private
  attr_reader :course, :slug, :page, :per

  def filter_slug!
    return if slug.blank?

    @levels = @levels.where("slug LIKE ?", "%#{Level.sanitize_sql_like(slug)}%")
  end
end
