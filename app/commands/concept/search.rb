class Concept::Search
  include Mandate

  DEFAULT_PAGE = 1
  DEFAULT_PER = 24

  def self.default_per = DEFAULT_PER

  def initialize(title: nil, page: nil, per: nil, user: nil)
    @title = title
    @page = page.present? && page.to_i.positive? ? page.to_i : DEFAULT_PAGE
    @per = per.present? && per.to_i.positive? ? per.to_i : self.class.default_per
    @user = user
  end

  def call
    @concepts = Concept.order(:title)

    apply_title_filter!
    apply_user_filter!

    @concepts.page(page).per(per)
  end

  private
  attr_reader :title, :page, :per, :user

  def apply_title_filter!
    return if title.blank?

    @concepts = @concepts.where("title ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(title)}%")
  end

  def apply_user_filter!
    return unless user

    @concepts = @concepts.where(id: user.unlocked_concept_ids)
  end
end
