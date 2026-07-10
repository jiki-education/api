class Challenge::Search
  include Mandate

  DEFAULT_PAGE = 1
  DEFAULT_PER = 24

  def self.default_per
    DEFAULT_PER
  end

  def initialize(title: nil, page: nil, per: nil, user: nil)
    @title = title
    @page = page.present? && page.to_i.positive? ? page.to_i : DEFAULT_PAGE
    @per = per.present? && per.to_i.positive? ? per.to_i : self.class.default_per
    @user = user
  end

  def call
    @challenges = Challenge.all
    apply_title_filter!
    apply_ordering!
    @challenges.page(page).per(per)
  end

  private
  attr_reader :title, :page, :per, :user

  def apply_title_filter!
    return if title.blank?

    @challenges = @challenges.where(
      "title ILIKE ?",
      "%#{ActiveRecord::Base.sanitize_sql_like(title)}%"
    )
  end

  def apply_ordering!
    return @challenges = @challenges.order(:title) unless user

    # Scope the join to the current user so other users' user_challenges don't filter challenges out.
    # NB: the underlying tables are still named projects / user_projects.
    @challenges = @challenges.
      joins(sanitize_sql_array(
        [
          "LEFT JOIN user_projects ON user_projects.project_id = projects.id AND user_projects.user_id = ?",
          user.id
        ]
      )).
      select("projects.*, CASE WHEN user_projects.user_id IS NOT NULL THEN 0 ELSE 1 END as lock_order").
      order("lock_order ASC, projects.title ASC")
  end

  def sanitize_sql_array(array)
    ActiveRecord::Base.sanitize_sql_array(array)
  end
end
