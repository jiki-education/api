module SPI
  class VideoProductionController < SPI::BaseController
    def executor_callback
      # Validate required parameters
      return render json: { error: 'node_uuid is required' }, status: :bad_request unless params[:node_uuid].present?

      return render json: { error: 'executor_type is required' }, status: :bad_request unless params[:executor_type].present?

      # Find the node
      node = VideoProduction::Node.find_by(uuid: params[:node_uuid])
      return render json: { error: "Node not found: #{params[:node_uuid]}" }, status: :not_found unless node

      # Process the callback (positional: node, executor_type; keyword: result, error, error_type, process_uuid)
      # Convert params to hash - permit all keys since this is an internal SPI endpoint
      VideoProduction::ProcessExecutorCallback.(
        node,
        params[:executor_type],
        result: params[:result]&.permit!&.to_h,
        error: params[:error],
        error_type: params[:error_type],
        process_uuid: params[:process_uuid]
      )

      render json: { status: 'ok' }, status: :ok
    rescue VideoProduction::ProcessExecutorCallback::StaleCallbackError => e
      # Stale callbacks are expected in distributed systems (e.g., retry after superseded execution)
      # Log but return 200 to prevent retries
      Rails.logger.warn("[SPI] Stale callback ignored: #{e.message}")
      render json: { status: 'ignored', reason: 'stale_callback' }, status: :ok
    rescue StandardError => e
      Rails.logger.error("[SPI] Executor callback failed: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      render json: { error: 'Internal server error' }, status: :internal_server_error
    end
  end
end
