module SPI
  class BaseController < ActionController::API
    # TODO: Add authentication for production
    # For production deployment, implement API key or token-based authentication
    # to ensure only the LLM proxy service can call these endpoints.
    # Example:
    #   before_action :verify_spi_token
    #
    #   private
    #   def verify_spi_token
    #     token = request.headers['X-SPI-Token']
    #     unless ActiveSupport::SecurityUtils.secure_compare(token, Jiki.secrets.spi_token)
    #       render json: { error: 'Unauthorized' }, status: :unauthorized
    #     end
    #   end
  end
end
