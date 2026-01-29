# Mailers

This document describes the email system architecture, patterns, and conventions for Jiki API.

## Technology Stack

### MJML + HAML
- **MJML**: Responsive email framework that compiles to HTML with inlined CSS
- **MRML**: Rust-based MJML compiler (faster, no Node.js dependency)
- **HAML**: Template language for cleaner syntax
- **Letter Opener**: Development tool that opens emails in browser instead of sending

### Why MJML?
MJML abstracts away email-specific HTML complexity:
- Automatically generates responsive HTML tables
- Inlines CSS for email client compatibility
- Works across all email clients including Outlook
- Compiles `.mjml.haml` → responsive HTML

## Configuration

### MJML Configuration
Located in `config/initializers/mjml.rb`:
- Uses MRML (Rust implementation) for speed
- HAML as template language
- Strict validation to catch errors early
- Environment-specific beautify/minify settings
- Production caching enabled

### Development Configuration
Located in `config/environments/development.rb`:
- Uses `letter_opener` gem to preview emails in browser
- No actual emails sent in development
- Emails automatically open in default browser

### Production Configuration
Located in `config/environments/production.rb`:

**Delivery Method:** AWS SES v2 API (not SMTP)
```ruby
config.action_mailer.delivery_method = :ses_v2
config.action_mailer.ses_v2_settings = { region: Jiki.config.ses_region }
```

**Authentication:** ECS task IAM role (no credentials needed in application)

**Why SES v2 API instead of SMTP:**
- API-level acknowledgment (more reliable than SMTP)
- No credentials to manage (IAM role handles auth automatically)
- Better integration with SES features (configuration sets, event notifications)
- Simpler infrastructure (no SMTP ports to manage)

**Config Values (via `Jiki.config`):**
| Key | Purpose | Example |
|-----|---------|---------|
| `ses_region` | AWS region for SES | eu-west-1 |
| `mail_from_email` | Transactional from address | hello@mail.jiki.io |
| `notifications_from_email` | Notifications from address | hello@notifications.jiki.io |
| `marketing_from_email` | Marketing from address | hello@hello.jiki.io |
| `support_email` | Reply-to for marketing | hello@jiki.io |
| `ses_mail_configuration_set` | SES config set for transactional | jiki-mail |
| `ses_notifications_configuration_set` | SES config set for notifications | jiki-notifications |
| `ses_marketing_configuration_set` | SES config set for marketing | jiki-marketing |

**Mailer Types:**
| Mailer | From Config | Configuration Set | Purpose |
|--------|------------|-------------------|---------|
| `TransactionalMailer` | mail_from_email | ses_mail_configuration_set | Critical: signups, password resets, receipts |
| `NotificationsMailer` | notifications_from_email | ses_notifications_configuration_set | Learning: completions, achievements |
| `MarketingMailer` | marketing_from_email | ses_marketing_configuration_set | Newsletters, announcements |

**Asset Host:** `Jiki.config.assets_cdn_url` (Cloudflare R2 CDN) for email images

## File Structure

**IMPORTANT**: MJML templates use `.mjml` extension (not `.html.mjml`) due to MRML compatibility. The `template_language = :haml` config handles HAML preprocessing.

```
app/
  mailers/
    application_mailer.rb          # Base mailer with locale support
    welcome_mailer.rb              # Example mailer
  views/
    layouts/
      mailer.mjml                  # MJML layout for all emails (HAML+MJML)
      mailer.text.erb              # Plain text layout
    mailers/
      shared/
        _header.mjml               # Reusable header component
        _footer.mjml               # Reusable footer component
    welcome_mailer/
      welcome.mjml                 # HTML email template (HAML+MJML)
      welcome.text.erb             # Plain text email template

config/
  locales/
    mailers/
      welcome_mailer.en.yml        # English translations
      welcome_mailer.hu.yml        # Hungarian translations
```

## Internationalization (i18n)

### Current Implementation (Phase 1)
- YAML files for English and Hungarian
- Structure: `config/locales/mailers/{mailer_name}.{locale}.yml`
- Uses standard Rails `t()` helper in templates

### Future Implementation (Phase 2)
- Database-backed i18n for 100+ languages
- YAML files as fallback
- No code changes required (transparent backend swap)

### Translation Key Structure
```yaml
en:
  mailer_name:
    action_name:
      subject: "Email subject"
      greeting: "Hi %{name},"
      body: "Email content"
      cta: "Call to action"
      footer: "Footer text"
```

## Creating a New Mailer

### 1. Generate Mailer
```ruby
# app/mailers/user_mailer.rb
class UserMailer < ApplicationMailer
  def notification(user, data:)
    with_locale(user) do
      @user = user
      @data = data

      mail(
        to: user.email,
        subject: t('.subject')
      )
    end
  end
end
```

### 2. Create MJML Template
**File extension must be `.mjml`**

```haml
# app/views/user_mailer/notification.mjml
- content_for :title, t('.subject')
- content_for :preview, t('.preview_text')

= render 'mailers/shared/header'

%mj-section{ "background-color": "#ffffff" }
  %mj-column
    %mj-text
      %h2= t('.greeting', name: @user.name)

    %mj-text
      %p= t('.body')

    %mj-button{ "href": @action_url, "background-color": "#0066cc" }
      = t('.cta')

= render 'mailers/shared/footer'
```

### 3. Create Text Template
```erb
# app/views/user_mailer/notification.text.erb
<%= t('.greeting', name: @user.name) %>

<%= t('.body') %>

<%= t('.cta') %>: <%= @action_url %>

---
<%= t('.footer') %>
```

### 4. Add Translations
```yaml
# config/locales/mailers/user_mailer.en.yml
en:
  user_mailer:
    notification:
      subject: "Subject line"
      preview_text: "Text shown in email preview"
      greeting: "Hi %{name},"
      body: "Email content"
      cta: "Button text"
      footer: "Footer text"
```

## Mailer Patterns

### Locale Management
All mailers inherit from `ApplicationMailer` which provides `with_locale`:

```ruby
def welcome(user)
  with_locale(user) do
    # All translations use user's preferred locale
    mail(to: user.email, subject: t('.subject'))
  end
end
```

### Always Include Both HTML and Text
- HTML: `.mjml.haml` file (responsive, styled)
- Text: `.text.erb` file (plain text, accessibility, spam filters)

### Use Reusable Components
- Header: `render 'mailers/shared/header'`
- Footer: `render 'mailers/shared/footer'`
- Consistent branding across all emails

### Content For (MJML Metadata)
```haml
- content_for :title, t('.subject')        # Email title tag
- content_for :preview, t('.preview_text') # Preview text in inbox
```

## MJML Components Reference

### Common Components
- `%mj-section`: Container for columns (like a row)
- `%mj-column`: Column inside a section (responsive grid)
- `%mj-text`: Text content with styling
- `%mj-button`: Call-to-action button
- `%mj-image`: Images with responsive sizing
- `%mj-spacer`: Vertical spacing

### Styling Pattern
```haml
%mj-text{ "color": "#333333", "font-size": "16px", "padding": "20px" }
  %p Content here
```

### CSS in MJML
For custom CSS in `%mj-style` tags, use the `:plain` filter to prevent HAML from processing it:

```haml
%mj-style
  :plain
    .custom-class { color: #0066cc; }
    .custom-class:hover { text-decoration: underline; }
```

### Responsive Design
MJML handles responsive behavior automatically:
- Mobile: Single column
- Desktop: Multi-column if specified
- All components stack on mobile

## Testing Emails in Development

### Via Rails Console
```ruby
# Create a test user object (doesn't need to be saved)
user = User.new(name: "Test User", email: "test@example.com", locale: "en")

# Send email - it will open in browser automatically
WelcomeMailer.welcome(user, login_url: "http://localhost:3000/login").deliver_now

# Test Hungarian version
user.locale = "hu"
WelcomeMailer.welcome(user, login_url: "http://localhost:3000/login").deliver_now
```

### Via Letter Opener
- Emails open automatically in default browser
- Stored in `tmp/letter_opener/`
- View both HTML and text versions
- Inspect compiled MJML output

## Email Deliverability Best Practices

### Subject Lines
- Keep under 50 characters
- Avoid spam trigger words (FREE, URGENT, etc.)
- Personalize when possible

### Content
- Include plain text version (improves spam score)
- Use real "from" address (hello@jiki.io)
- Include unsubscribe link (required by law)
- Test across email clients

### Technical
- MJML ensures proper HTML structure
- CSS automatically inlined
- Responsive by default
- Valid HTML output

## Production Considerations

### AWS SES Setup (Configured)
Production uses SES v2 API with:
- IAM role authentication (ECS task role)
- Verified sender domains (mail.jiki.io, notifications.jiki.io, hello.jiki.io)
- Configuration sets for tracking and dedicated IP routing
- Region: eu-west-1

### Monitoring
- SES configuration sets enable event notifications
- Monitor bounce rates via SES console
- Log failed deliveries in Rails logs
- Solid Queue handles retry for background jobs

### Performance
- Use background jobs for sending (Solid Queue + Active Job)
- MJML templates cached in production
- Batch sends when appropriate

## Troubleshooting

### MJML Compilation Errors
- Check `validation_level: 'strict'` catches errors early
- Verify HAML syntax (indentation matters)
- Ensure all MJML components are properly closed

### Translations Missing
- Check locale file exists: `config/locales/mailers/{mailer}.{locale}.yml`
- Verify key structure matches template `t()` calls
- Ensure locale is set correctly on user model

### Letter Opener Not Opening
- Verify `delivery_method: :letter_opener` in development.rb
- Check `perform_deliveries: true`
- Look for errors in Rails logs

### Styling Issues
- Use MJML components instead of raw HTML
- Test in multiple email clients
- Use inline styles for anything not in MJML components
- Check MJML documentation for component options

## Related Files
- Configuration: `.context/configuration.md`
- Testing: `.context/testing.md`
- Commands: `.context/commands.md`
