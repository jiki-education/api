class Badge < ApplicationRecord
  include Translatable

  has_many :acquired_badges, class_name: "User::AcquiredBadge", dependent: :destroy
  has_many :translations, class_name: "Badge::Translation", dependent: :destroy

  scope :secret, -> { where(secret: true) }

  self.translatable_fields = %i[name description fun_fact email_subject email_content_markdown]

  # Class method to store badge metadata
  def self.seed(name, icon, description, fun_fact: nil, secret: false)
    @seed_data = {
      name:,
      icon:,
      description:,
      fun_fact:,
      secret:
    }
  end

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
    seed_data = self.class.instance_variable_get("@seed_data")
    next unless seed_data

    self.name = seed_data[:name]
    self.icon = seed_data[:icon]
    self.description = seed_data[:description]
    self.fun_fact = seed_data[:fun_fact]
    self.secret = seed_data[:secret]
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
