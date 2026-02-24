class Concept < ApplicationRecord
  include HasVideoData

  disable_sti!

  extend FriendlyId
  friendly_id :slug, use: [:history]

  MAX_DEPTH = 10

  has_video_data :video_data

  belongs_to :unlocked_by_lesson, class_name: 'Lesson', optional: true
  belongs_to :parent,
    class_name: 'Concept',
    optional: true,
    foreign_key: :parent_concept_id,
    counter_cache: :children_count,
    inverse_of: :children
  has_many :children, class_name: 'Concept', foreign_key: :parent_concept_id, dependent: :nullify, inverse_of: :parent
  has_many :lesson_concepts, dependent: :destroy
  has_many :lessons, through: :lesson_concepts

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :description, presence: true
  validates :content_markdown, presence: true
  validate :validate_no_circular_reference!, on: :update, if: :parent_concept_id_changed?
  validate :validate_depth_within_limit!, if: :parent_concept_id_changed?

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

  # Returns the parent, children, and siblings of this concept.
  # For root concepts (parent_concept_id is NULL), SQL's NULL equality
  # semantics naturally exclude the parent and sibling clauses,
  # so only children are returned.
  def related_concepts
    Concept.where(
      "id = :parent_id OR parent_concept_id = :self_id OR (parent_concept_id = :parent_id AND id != :self_id)",
      parent_id: parent_concept_id,
      self_id: id
    ).limit(6)
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

  def validate_no_circular_reference!
    return unless parent_concept_id

    if parent_concept_id == id
      errors.add(:parent_concept_id, "cannot be the concept itself")
      return
    end

    return unless parent&.ancestor_ids&.include?(id)

    errors.add(:parent_concept_id, "would create a circular reference")
  end

  def validate_depth_within_limit!
    return unless parent_concept_id

    return unless ancestors.length >= MAX_DEPTH

    errors.add(:parent_concept_id, "would exceed maximum nesting depth of #{MAX_DEPTH}")
  end
end
