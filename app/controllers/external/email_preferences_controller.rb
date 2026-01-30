class External::EmailPreferencesController < ApplicationController
  before_action :use_user_by_token!

  def show
    render json: { email_preferences: SerializeEmailPreferences.(@user) }
  end

  def update
    preference_params.each do |slug, value|
      User::UpdateNotificationPreference.(@user, slug, value)
    end
    render json: { email_preferences: SerializeEmailPreferences.(@user) }
  rescue InvalidNotificationSlugError
    render_not_found("Unknown notification type")
  end

  def unsubscribe_all
    User::UnsubscribeFromAllEmails.(@user)
    render json: { email_preferences: SerializeEmailPreferences.(@user) }
  end

  def subscribe_all
    User::SubscribeToAllEmails.(@user)
    render json: { email_preferences: SerializeEmailPreferences.(@user) }
  end

  private
  def use_user_by_token!
    @user = User.joins(:data).find_by(user_data: { unsubscribe_token: params[:token] })
    raise InvalidUnsubscribeTokenError unless @user
  rescue InvalidUnsubscribeTokenError
    render json: {
      error: {
        type: "not_found",
        message: "Invalid or expired unsubscribe token"
      }
    }, status: :not_found
  end

  def preference_params
    params.permit(:newsletters, :event_emails, :milestone_emails, :activity_emails)
  end
end
