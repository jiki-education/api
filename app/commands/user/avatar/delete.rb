class User::Avatar::Delete
  include Mandate

  initialize_with :user

  def call
    ActiveRecord::Base.transaction do
      user.avatar.purge if user.avatar.attached?
      user.update!(avatar_url: nil)
    end
  end
end
