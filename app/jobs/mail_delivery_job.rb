# Rails' default ActionMailer::MailDeliveryJob inherits ActiveJob::Base, not
# ApplicationJob, so it gets no retries: a single transient failure leaves the
# email permanently in Solid Queue's failed executions, unsent.
#
# On ECS, the task's credentials occasionally go stale, surfacing as one of:
# - MissingCredentialsError: the credential fetch from the container metadata
#   endpoint timed out, caught when the SES request is signed — strictly
#   BEFORE any HTTP call to SES (Sentry JIKI-API-N).
# - SESV2 ExpiredTokenException: the worker signed with credentials past
#   expiry and SES rejected the request at auth — an auth rejection happens
#   before SES accepts the message, so the email was not sent (JIKI-API-T).
#
# In both cases no email can have been sent, so retrying can never
# double-send. Do NOT broaden this to other errors (e.g. network timeouts,
# generic StandardError): those can fire AFTER SES has accepted the message,
# and a retry would send the email twice.
class MailDeliveryJob < ActionMailer::MailDeliveryJob
  retry_on Aws::Errors::MissingCredentialsError, wait: :polynomially_longer, attempts: 10
  retry_on Aws::SESV2::Errors::ExpiredTokenException, wait: :polynomially_longer, attempts: 10
end
