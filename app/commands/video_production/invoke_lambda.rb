class VideoProduction::InvokeLambda
  include Mandate

  initialize_with :function_name, :payload

  def call
    response = Jiki.lambda_client.invoke(
      function_name: function_name,
      invocation_type: 'Event', # Asynchronous - fire and forget
      payload: JSON.generate(payload)
    )

    # For async invocations, 202 = accepted
    raise "Lambda invocation failed with status #{response.status_code}" if response.status_code != 202

    # Async invocation returns immediately - no result payload
    # Lambda will callback to SPI endpoint when complete
    { status: 'invoked' }
  rescue Aws::Lambda::Errors::ServiceError => e
    raise "AWS Lambda error: #{e.message}"
  end
end
