# Rails' default ActionMailer::MailDeliveryJob inherits ActiveJob::Base, not
# ApplicationJob, so it gets no retries: a single transient failure leaves the
# email permanently in Solid Queue's failed executions, unsent.
#
# On ECS, the SDK's credential fetch from the container metadata endpoint
# occasionally times out, surfacing as MissingCredentialsError when the SES
# request is signed. Signing happens strictly BEFORE any HTTP call to SES, so
# retrying this error can never double-send an email.
#
# Do NOT broaden this to other errors (e.g. network timeouts, generic
# StandardError): those can fire AFTER SES has accepted the message, and a
# retry would send the email twice.
class MailDeliveryJob < ActionMailer::MailDeliveryJob
  retry_on Aws::Errors::MissingCredentialsError, wait: :polynomially_longer, attempts: 10
end
