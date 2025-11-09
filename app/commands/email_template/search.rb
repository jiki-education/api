class EmailTemplate::Search
  include Mandate

  DEFAULT_PAGE = 1
  DEFAULT_PER = 24

  def self.default_per
    DEFAULT_PER
  end

  def initialize(type: nil, slug: nil, locale: nil, page: nil, per: nil)
    @type = type
    @slug = slug
    @locale = locale
    @page = page.present? && page.to_i.positive? ? page.to_i : DEFAULT_PAGE
    @per = per.present? && per.to_i.positive? ? per.to_i : self.class.default_per
  end

  def call
    @email_templates = EmailTemplate.all

    filter_type!
    filter_slug!
    filter_locale!

    @email_templates.order(:id).page(page).per(per)
  end

  private
  attr_reader :type, :slug, :locale, :page, :per

  def filter_type!
    return if type.blank?

    @email_templates = @email_templates.where(type:)
  end

  def filter_slug!
    return if slug.blank?

    @email_templates = @email_templates.where("slug LIKE ?", "%#{EmailTemplate.sanitize_sql_like(slug)}%")
  end

  def filter_locale!
    return if locale.blank?

    @email_templates = @email_templates.where(locale:)
  end
end
