class Internal::SettingsController < Internal::BaseController
  # TODO: Re-enable once frontend supports sudo password verification
  # before_action :validate_sudo!, only: %i[email password]

  def show
    render json: { settings: SerializeSettings.(current_user) }
  end

  def name
    User::UpdateName.(current_user, params[:value])
    render json: { settings: SerializeSettings.(current_user) }
  rescue ActiveRecord::RecordInvalid => e
    render_422(:name_update_failed, errors: e.record.errors.as_json)
  end

  def email
    User::UpdateEmail.(current_user, params[:value])
    render json: { settings: SerializeSettings.(current_user) }
  rescue ActiveRecord::RecordInvalid => e
    render_422(:email_update_failed, errors: e.record.errors.as_json)
  end

  def password
    User::UpdatePassword.(current_user, params[:value])
    render json: { settings: SerializeSettings.(current_user) }
  rescue ActiveRecord::RecordInvalid => e
    render_422(:password_update_failed, errors: e.record.errors.as_json)
  end

  def locale
    User::UpdateLocale.(current_user, params[:value])
    render json: { settings: SerializeSettings.(current_user) }
  rescue ActiveRecord::RecordInvalid => e
    render_422(:locale_update_failed, errors: e.record.errors.as_json)
  end

  def handle
    User::UpdateHandle.(current_user, params[:value])
    render json: { settings: SerializeSettings.(current_user) }
  rescue ActiveRecord::RecordInvalid => e
    render_422(:handle_update_failed, errors: e.record.errors.as_json)
  end

  def notification
    User::UpdateNotificationPreference.(current_user, params[:slug], params[:value])
    render json: { settings: SerializeSettings.(current_user) }
  rescue InvalidNotificationSlugError
    render_404(:not_found)
  rescue ActiveRecord::RecordInvalid => e
    render_422(:notification_update_failed, errors: e.record.errors.as_json)
  end

  def streaks
    User::UpdateStreaksEnabled.(current_user, params[:enabled])
    render json: { settings: SerializeSettings.(current_user) }
  rescue ActiveRecord::RecordInvalid => e
    render_422(:streaks_update_failed, errors: e.record.errors.as_json)
  end
end
