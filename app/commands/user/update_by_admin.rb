class User::UpdateByAdmin
  include Mandate

  initialize_with :user, :params

  def call
    guard_root_admin_demotion!

    # Skip reconfirmation for admin-initiated email changes
    user.skip_reconfirmation! if filtered_params[:email].present?
    user.update!(filtered_params)
    user
  end

  private
  def guard_root_admin_demotion!
    return unless demoting_root_admin?

    user.errors.add(:admin, "cannot be revoked for the root admin")
    raise ActiveRecord::RecordInvalid, user
  end

  def demoting_root_admin?
    return false unless user.root_admin?
    return false unless filtered_params.key?(:admin)

    !ActiveModel::Type::Boolean.new.cast(filtered_params[:admin])
  end

  memoize
  def filtered_params
    params.slice(:email, :admin)
  end
end
