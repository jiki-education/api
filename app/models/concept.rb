class Concept < ApplicationRecord
  disable_sti!

  extend FriendlyId
  friendly_id :slug, use: [:history]

  VIDEO_PROVIDERS = %w[youtube mux].freeze

  belongs_to :unlocked_by_lesson, class_name: 'Lesson', optional: true

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :description, presence: true
  validates :content_markdown, presence: true
  validates :standard_video_provider, inclusion: { in: VIDEO_PROVIDERS, allow_nil: true }
  validates :premium_video_provider, inclusion: { in: VIDEO_PROVIDERS, allow_nil: true }

  before_validation :generate_slug, on: :create
  before_save :parse_markdown, if: :content_markdown_changed?

  def to_param = slug

  private
  def generate_slug
    return if slug.present?
    return if title.blank?

    self.slug = title.parameterize
  end

  def parse_markdown
    self.content_html = Utils::Markdown::Parse.(content_markdown)
  end
end
