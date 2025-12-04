class UserLevel::Start
  include Mandate

  initialize_with :user, :level

  def call
    ActiveRecord::Base.transaction do
      UserLevel.find_create_or_find_by!(user:, level:).tap do |user_level|
        # Only update tracking pointer on first creation
        user.update!(current_user_level: user_level) if user_level.just_created?
      end
    end
  end
end
