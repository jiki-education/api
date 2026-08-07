class Concept::Search
  include Mandate

  DEFAULT_PAGE = 1
  DEFAULT_PER = 24

  def self.default_per = DEFAULT_PER

  # Concepts carry no copy here any more, so `query` matches on slug. Callers
  # wanting to search human-readable titles should filter the front-end
  # catalogue, which is where those titles live (and are translated).
  def initialize(query: nil, slugs: nil, page: nil, per: nil, user: nil)
    @query = query
    @slugs = slugs
    @page = page.present? && page.to_i.positive? ? page.to_i : DEFAULT_PAGE
    @per = per.present? && per.to_i.positive? ? per.to_i : self.class.default_per
    @user = user
  end

  def call
    @concepts = Concept.includes(:unlocked_by_lesson).order(:slug)

    apply_query_filter!
    apply_slugs_filter!
    apply_user_specific_ordering!

    @concepts.page(page).per(per)
  end

  private
  attr_reader :query, :slugs, :page, :per, :user

  def apply_query_filter!
    return if query.blank?

    @concepts = @concepts.where("slug ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(query)}%")
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
      reorder(Arel.sql("lock_order ASC, concepts.slug ASC"))
  end
end
