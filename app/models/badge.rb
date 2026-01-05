class Badge < ApplicationRecord
  has_many :acquired_badges, class_name: "User::AcquiredBadge", dependent: :destroy
  scope :secret, -> { where(secret: true) }

  # Class method to store badge metadata
  def self.seed(name, icon, description, secret: false)
    @seed_data = {
      name:,
      icon:,
      description:,
      secret:
    }
  end

  # Find badge by slug and create on-demand
  def self.find_by_slug!(slug)
    klass = "badges/#{slug}_badge".camelize.constantize

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
    self.secret = seed_data[:secret]
  end

  # Abstract method - must be implemented by subclasses
  def award_to?(user)
    raise NotImplementedError, "Subclasses must implement award_to?"
  end

  # Calculate percentage of users who have this badge
  def percentage_awardees
    return 0 if num_awardees.zero?

    total_users = User.count
    return 0 if total_users.zero?

    ((num_awardees.to_f / total_users) * 100).round(2)
  end
end
