class Webhooks::ExercismController < Webhooks::BaseController
  # POST /webhooks/exercism
  def create
    payload = request.body.read
    signature_header = request.env["HTTP_X_EXERCISM_SIGNATURE"]

    begin
      Exercism::Webhook::HandleEvent.(payload, signature_header)
      head :ok
    rescue InvalidExercismWebhookSignatureError => e
      Rails.logger.error("Exercism webhook signature verification failed: #{e.message}")
      head :unauthorized
    rescue JSON::ParserError => e
      Rails.logger.error("Exercism webhook malformed payload: #{e.message}")
      head :unprocessable_entity
    rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::LockWaitTimeout => e
      Rails.logger.error("Exercism webhook transient error: #{e.message}")
      head :internal_server_error
    rescue StandardError => e
      Rails.logger.error("Exercism webhook processing error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      head :ok
    end
  end
end
