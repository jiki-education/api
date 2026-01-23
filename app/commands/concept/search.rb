class Concept::Search
  include Mandate

  DEFAULT_PAGE = 1
  DEFAULT_PER = 24

  def self.default_per = DEFAULT_PER

  def initialize(title: nil, slugs: nil, page: nil, per: nil, user: nil)
    @title = title
    @slugs = slugs
    @page = page.present? && page.to_i.positive? ? page.to_i : DEFAULT_PAGE
    @per = per.present? && per.to_i.positive? ? per.to_i : self.class.default_per
    @user = user
  end

  def call
    @concepts = Concept.order(:title)

    apply_title_filter!
    apply_slugs_filter!
    apply_user_specific_ordering!

    @concepts.page(page).per(per)
  end

  private
  attr_reader :title, :slugs, :page, :per, :user

  def apply_title_filter!
    return if title.blank?

    @concepts = @concepts.where("title ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(title)}%")
  end

  def apply_slugs_filter!
    return if slugs.blank?

    slug_array = slugs.split(',').map(&:strip).reject(&:blank?)
    return if slug_array.empty?

    @concepts = @concepts.where(slug: slug_array)
  end

  def apply_user_specific_ordering!
    return unless user && user.unlocked_concept_ids.present?

    sql = "concepts.*, CASE WHEN concepts.id = ANY(ARRAY[?]::bigint[]) THEN 0 ELSE 1 END as lock_order"
    sanitized = ActiveRecord::Base.sanitize_sql_array([sql, user.unlocked_concept_ids])

    @concepts = @concepts.
      select(Arel.sql(sanitized)).
      reorder(Arel.sql("lock_order ASC, concepts.title ASC"))
  end
end
