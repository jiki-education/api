class Badge < ApplicationRecord
  # Dropped in a follow-up migration; ignored here so this code never selects
  # them and the drop is safe once this deploy has rolled out.
  self.ignored_columns += %w[name description fun_fact]
  include Translatable

  has_many :acquired_badges, class_name: "User::AcquiredBadge", dependent: :destroy
  has_many :translations, class_name: "Badge::Translation", dependent: :destroy

  scope :secret, -> { where(secret: true) }

  # Email copy only - names, descriptions and fun facts are authored in the
  # front-end curriculum repo (curriculum/src/badges/locales/).
  self.translatable_fields = %i[email_subject email_content_markdown]

  # Class method to store badge metadata. Copy lives in the front-end
  # curriculum repo, so all a badge declares here is whether it is secret.
  def self.seed(secret: false)
    @seed_data = { secret: }
  end

  # Badge attributes defined by the subclass's `seed` call. Subclasses that
  # don't call `seed` are non-secret. Never nil, so db/seeds.rb always persists
  # and re-syncs every badge.
  def self.seed_data = @seed_data || { secret: false }

  # Find badge by slug and create on-demand
  def self.find_by_slug!(slug)
    # Validate slug format (only lowercase letters and underscores)
    raise ArgumentError, "Invalid badge slug: #{slug}" unless slug.match?(/\A[a-z_]+\z/)

    klass = "badges/#{slug}_badge".camelize.safe_constantize
    raise ArgumentError, "Badge class not found for slug: #{slug}" unless klass

    # Race condition safe
    begin
      klass.first || klass.create!
    rescue ActiveRecord::RecordNotUnique
      klass.first
    end
  end

  # Set attributes from seed data before creation
  before_create do
    self.secret = self.class.seed_data[:secret]
  end

  # Abstract method - must be implemented by subclasses
  def award_to?(user)
    raise NotImplementedError, "Subclasses must implement award_to?"
  end

  # Derive slug from class name (e.g., Badges::MemberBadge -> "member")
  def slug
    self.class.name.demodulize.underscore.delete_suffix('_badge')
  end

  # Calculate percentage of users who have this badge
  def percentage_awardees
    return 0 if num_awardees.zero?

    total_users = User.count
    return 0 if total_users.zero?

    ((num_awardees.to_f / total_users) * 100).round(2)
  end
end
