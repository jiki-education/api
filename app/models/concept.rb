class Concept < ApplicationRecord
  disable_sti!

  extend FriendlyId
  friendly_id :slug, use: [:history]

  VIDEO_PROVIDERS = %w[youtube mux].freeze

  belongs_to :unlocked_by_lesson, class_name: 'Lesson', optional: true
  belongs_to :parent,
    class_name: 'Concept',
    optional: true,
    foreign_key: :parent_concept_id,
    counter_cache: :children_count,
    inverse_of: :children
  has_many :children, class_name: 'Concept', foreign_key: :parent_concept_id, dependent: :nullify, inverse_of: :parent

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :description, presence: true
  validates :content_markdown, presence: true
  validates :standard_video_provider, inclusion: { in: VIDEO_PROVIDERS, allow_nil: true }
  validates :premium_video_provider, inclusion: { in: VIDEO_PROVIDERS, allow_nil: true }
  validate :parent_cannot_create_circular_reference, if: :parent_concept_id_changed?

  before_validation :generate_slug, on: :create
  before_save :parse_markdown, if: :content_markdown_changed?

  def to_param = slug

  def ancestors
    return [] unless parent_concept_id

    Concept.find_by_sql([ANCESTORS_SQL, { parent_id: parent_concept_id }])
  end

  def ancestor_ids
    ancestors.map(&:id)
  end

  ANCESTORS_SQL = <<~SQL.freeze
    WITH RECURSIVE ancestor_tree AS (
      SELECT id, title, slug, parent_concept_id, 1 AS depth
      FROM concepts
      WHERE id = :parent_id

      UNION ALL

      SELECT c.id, c.title, c.slug, c.parent_concept_id, at.depth + 1
      FROM concepts c
      INNER JOIN ancestor_tree at ON c.id = at.parent_concept_id
    )
    SELECT id, title, slug FROM ancestor_tree ORDER BY depth DESC
  SQL

  def root?
    parent_concept_id.nil?
  end

  def has_children?
    children_count.positive?
  end

  private
  def generate_slug
    return if slug.present?
    return if title.blank?

    self.slug = title.parameterize
  end

  def parse_markdown
    self.content_html = Utils::Markdown::Parse.(content_markdown)
  end

  def parent_cannot_create_circular_reference
    return unless parent_concept_id

    if parent_concept_id == id
      errors.add(:parent_concept_id, "cannot be the concept itself")
      return
    end

    return unless persisted?

    return unless parent.ancestor_ids.include?(id)

    errors.add(:parent_concept_id, "would create a circular reference")
  end
end
