## Piwik Integration

Piwik Analytics is an open-source analytics platform which provides 100% user data ownership. It provides a powerful, customizable, and extensible analytics solution with visual tools to help clients make business decisions from real-time data metrics. [Piwik Analytics](https://piwik.org/)

Piwik Integration gem allows users to more easily:
1. Create user accounts with auto-generated usernames and passwords. 
2. Track number, date, and time of occurrence of all page loads from all people visiting their website.  
3. Provide information on all the devices being used to visit their website, such as: type of device used (smartphone or PC), OS  (Android, iOS, Windows, MacOSX), and browser used (Chrome, Firefox, etc.)  
4. Create goals and track goal conversions.
5. Track number, dollar amount, date, and time of occurrence of all donations from all people visiting their website. 
6. Log users into Piwik dashboard where they have visual analytics data from real-time metrics.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'piwik_integration', :git => 'git@github.com:ahdelgado/piwik_integration.git'
```

And then execute:

    $ bundle install

## Usage

I used an iframe to log into Piwik using view code such as:

```html
<iframe align="center" height="2000" src="<%= @analytics_url %>" width="100%"></iframe>
```
The @analytics_url is returned by the login_to_piwik gem method. Example:

```ruby
@piwik_service = PiwikService.new(CONFIG[:form_metrics][:metrics_token_auth],
                       CONFIG[:form_metrics][:metrics_admin_url],
                       CONFIG[:form_metrics][:metrics_post_url],
                       CONFIG[:form_metrics][:metrics_js_url],
                       CONFIG[:form_metrics][:metrics_timeout],
                       @customer.id)
@piwik_service.set_param(:ua, @user_agent)
@analytics_url = @piwik_service.login_to_piwik
```

You will need to do some setup work in your code base such as defining a method to track posts, which then calls the gem methods. The gem only handles the logic for sending API calls to Piwik. 

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ahdelgado/piwik_integration.

