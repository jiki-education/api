class Project::Search
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
    @projects = Project.all
    apply_title_filter!
    apply_ordering!
    @projects.page(page).per(per)
  end

  private
  attr_reader :title, :page, :per, :user

  def apply_title_filter!
    return if title.blank?

    @projects = @projects.where(
      "title ILIKE ?",
      "%#{ActiveRecord::Base.sanitize_sql_like(title)}%"
    )
  end

  def apply_ordering!
    if user
      # Order by whether user has unlocked the project (unlocked first), then by title
      @projects = @projects.
        left_joins(:user_projects).
        where("user_projects.user_id IS NULL OR user_projects.user_id = ?", user.id).
        select(sanitize_sql_array(["projects.*, CASE WHEN user_projects.user_id = ? THEN 0 ELSE 1 END as lock_order", user.id])).
        order("lock_order ASC, projects.title ASC").
        distinct
    else
      # Default ordering by title
      @projects = @projects.order(:title)
    end
  end

  def sanitize_sql_array(array)
    ActiveRecord::Base.sanitize_sql_array(array)
  end
end
