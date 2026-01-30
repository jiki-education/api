class User < ApplicationRecord
  extend Mandate::Memoize

  # Include default devise modules. Others available are:
  # :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
    :recoverable, :validatable, :confirmable

  has_one_attached :avatar

  has_one :data, dependent: :destroy, class_name: "User::Data", autosave: true
  has_one :activity_data, dependent: :destroy, class_name: "User::ActivityData", autosave: true

  has_many :user_courses, dependent: :destroy
  has_many :courses, through: :user_courses
  has_many :user_lessons, dependent: :destroy
  has_many :lessons, through: :user_lessons
  has_many :user_levels, dependent: :destroy
  has_many :levels, through: :user_levels
  has_many :user_projects, dependent: :destroy
  has_many :projects, through: :user_projects
  has_many :acquired_badges, class_name: "User::AcquiredBadge", dependent: :destroy
  has_many :badges, through: :acquired_badges
  has_many :assistant_conversations, dependent: :destroy
  has_many :payments, dependent: :destroy

  after_initialize do
    build_data if new_record? && !data
    build_activity_data if new_record? && !activity_data
  end

  validates :locale, presence: true, inclusion: { in: %w[en hu] }
  validates :handle, presence: true, uniqueness: true

  # OAuth users have random passwords, so skip password validation for them
  validates :password, presence: true, if: -> { new_record? && provider.nil? && encrypted_password.blank? }

  # Placeholder for communication preferences - will be implemented later
  def communication_preferences
    nil
  end

  # Activity/streak methods
  def current_streak = aggregate_activity_data[:current_streak]
  def total_active_days = aggregate_activity_data[:total_active_days]

  memoize
  def aggregate_activity_data = User::ActivityLog::SyncAndRetrieveAggregates.(self)

  # Delegate unknown methods to data record
  def method_missing(name, *args)
    super
  rescue NameError
    raise unless data.respond_to?(name)

    data.send(name, *args)
  end

  def respond_to_missing?(name, *args)
    super || data.respond_to?(name)
  end

  # Don't rely on respond_to_missing? which n+1s a data record
  # https://tenderlovemaking.com/2011/06/28/til-its-ok-to-return-nil-from-to_ary.html
  def to_ary
    nil
  end
end
