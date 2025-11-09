module SPI
  class BaseController < ActionController::API
    # SPI endpoints are network-guarded and don't require authentication
    # They should only be accessible from trusted networks/services

    # Log all SPI requests for security audit
    before_action :log_spi_request

    private
    def log_spi_request
      Rails.logger.info("[SPI] #{request.method} #{request.path} from #{request.remote_ip}")
    end
  end
end
