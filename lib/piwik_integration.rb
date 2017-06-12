require "piwik_integration/version"

class PiwikIntegration


  def initialize(token_auth, admin_url, post_url, js_url, timeout, customer_id=0)
    @customer_id                    = customer_id.to_i
    raise 'PiwikIntegration: must pass non-zero numeric customer id to new method'  unless is_customer_id_valid?
    @metrics_admin_url              = admin_url
    @metrics_post_url               = post_url
    @js_url                         = js_url
    @metrics_params                 = Hash.new
    @metrics_params[:access]        = 'admin'
    @metrics_params[:token_auth]    = token_auth
    @metrics_params[:module]        = 'API'
    @metrics_params[:action]        = 'logme'
    @metrics_params[:patternType]   = 'xml'
    @metrics_params[:ecommerce]     = '1'
    @metrics_params[:timezone]      = 'UTC'
    @metrics_params[:rec]           = '1'
    @metrics_params[:apiv]          = '1'
    @metrics_params[:send_image]    = '0'
    @metrics_params[:action_name]   = 'ADMIN'
    @metrics_params[:timeout]      = timeout
  end

#=======================================================================================================================
#   GOAL METHODS
#=======================================================================================================================
  def create_goal(p_name, p_matchAttribute, p_pattern, p_patternType, metrics_site_id)
    set_param(:idSite,          metrics_site_id)
    set_param(:method,          'Goals.addGoal')
    set_param(:name,            p_name)
    set_param(:matchAttribute,  p_matchAttribute)
    set_param(:pattern,         p_pattern)
    set_param(:patternType,     p_patternType)
    url_string =  @metrics_admin_url + @metrics_params.slice(:module, :method, :idSite, :name, :matchAttribute,
                                                            :pattern, :patternType, :token_auth).to_query
    response_string = api_call(url_string)
    metrics_goal_id = response_string.xpath('//result/text()').map(&:text)[0]
    metrics_goal_id.to_i
  end

  def get_goals
    set_param(:method,      'Goals.getGoals')
    url_string =  @metrics_admin_url + @metrics_params.slice(:module, :method, :idSite, :token_auth).to_query
    xstring = api_call(url_string)
    goals = xstring.xpath('//name/text()').map(&:text)
  end

  def goal_exists?
    goals = get_goals
    goals != []
  end
#=======================================================================================================================
#   END:  GOAL METHODS
#=======================================================================================================================



#=======================================================================================================================
#   USER METHODS
#=======================================================================================================================
  def create_user(user_email=nil)
    if user_email == nil                             # post path
      email = get_param(:user_email)
    else
      email = user_email                             # login path
    end
    user     = make_user_name
    password = make_user_password
    set_param(:method,         'UsersManager.addUser')
    set_param(:userLogin,      user)
    set_param(:email,          email)
    set_param(:password,       password)
    url_string =  @metrics_admin_url+ @metrics_params.slice(:module, :method, :userLogin, :password, :email,
                                                           :token_auth).to_query
    metrics_admin_call(url_string)
  end

  def delete_user
    user = make_user_name
    set_param(:method,         'UsersManager.deleteUser')
    set_param(:userLogin, user)
    url_string =  @metrics_admin_url + @metrics_params.slice(:module, :method, :userLogin, :token_auth).to_query
    metrics_admin_call(url_string)
  end

  def get_token_auth
    user = make_user_name
    password = make_user_password
    set_param(:method,          'UsersManager.getTokenAuth')
    set_param(:userLogin,       user)
    set_param(:md5Password,     hashit(password))
    url_string =  @metrics_admin_url + @metrics_params.slice(:module, :method, :userLogin, :md5Password).to_query
    xstring = api_call(url_string)
    token_auth = xstring.xpath('//result/text()').map(&:text)[0]
  end

  def get_user_with_access_to_customer
    set_param(:method,          'UsersManager.getUsersAccessFromSite')
    set_param(:format,          'JSON')
    url_string =  @metrics_admin_url + @metrics_params.slice(:module, :method, :format, :idSite, :token_auth).to_query
    uri = URI.parse(url_string)
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Get.new(uri.request_uri)
    http.read_timeout = get_param(:timeout)
    http.use_ssl = true
    set_param(:format,  'xml')
    begin
      response = http.request(request)
      puts "Response: #{response.code} #{response.message} #{response.class.name}"
      result = response.body.tr('[{}]', '')
      puts 'User: ' + result
      result
    rescue
      print 'FORM METRICS ADMIN FAIL:'
    end
  end

  def login
    user = make_user_name
    password = make_user_password
    set_param(:action_name,     'LOGIN')
    set_param(:module,          'Login')
    set_param(:login,           user)
    set_param(:password,        hashit(password))
    url_string =  @metrics_admin_url + @metrics_params.slice(:module, :action, :login, :password).to_query
    set_param(:module,          'API')
    api_call(url_string)
    set_param(:action_name,     'ADMIN')
    url_string
  end

  def customer_verify(website_name=nil, user_email=nil)
    if website_exists_in_piwik?(website_name)
      site_id = get_site_id(website_name)
    else
      site_id = create_website(website_name)
    end
    set_param(:idSites, site_id)
    set_param(:idSite,  site_id)
    unless user_exists_in_piwik?
      create_user(user_email)
      set_user_access
    end
    site_id.to_i
  end

  def set_user_access
    user = make_user_name
    set_param(:method,          'UsersManager.setUserAccess')
    set_param(:userLogin,       user)
    url_string =  @metrics_admin_url + @metrics_params.slice(:module, :method, :userLogin, :access, :idSites,
                                                            :token_auth).to_query
    metrics_admin_call(url_string)
  end

  def user_exists_in_piwik?
    user = make_user_name
    set_param(:method,          'UsersManager.userExists')
    set_param(:userLogin,       user)
    url_string =  @metrics_admin_url + @metrics_params.slice(:module, :method, :userLogin, :token_auth).to_query
    xstring = api_call(url_string)
    user_exists = xstring.xpath('//result/text()').map(&:text)[0]
    user_exists == '1'
  end

  def make_user_name
    full_id = ('x' + format_customer_id).rjust(11,'ulhe349m2r5')
    new_id = "mc_user_#{full_id}"
  end

  def make_user_password
    full_id = ('x' + format_customer_id).rjust(11,'a7nrk3qy423')
    new_id = "mc_pw#{full_id}"
  end

  def format_customer_id
     StringUtil.pad_string(@customer_id.to_s, 4, '0')
  end


#=======================================================================================================================
#   END:  USER METHODS
#=======================================================================================================================


#=======================================================================================================================
#   WEBSITE METHODS
#=======================================================================================================================
  def create_website(website_name=nil)
    set_param(:method,          'SitesManager.addSite')
    if website_name == nil                                        # post path
      set_param(:siteName,        get_param(:website_name))
      set_param(:urls,            get_param(:website_name))
    else                                                          # login path
      set_param(:siteName,        website_name)
      set_param(:urls,            website_name)
    end

    url_string =  @metrics_admin_url + @metrics_params.slice(:module, :method, :siteName, :urls, :ecommerce, :timezone,
                                                            :token_auth).to_query
    xstring = api_call(url_string)
    site_id = xstring.xpath('//result/text()').map(&:text)[0]
    set_param(:idSite, site_id)
    site_id.to_i
  end

  def delete_website_and_user
    user = make_user_name
    set_param(:access,          'noaccess')
    set_user_access
    set_param(:access,          'admin')
    delete_user
    set_param(:method,          'SitesManager.deleteSite')
    url_string =  @metrics_admin_url + @metrics_params.slice(:module, :method, :idSite, :token_auth).to_query
    metrics_admin_call(url_string)
  end

  def get_site_id(website_name=nil)
    set_param(:method,          'SitesManager.getSitesIdFromSiteUrl')
    if website_name == nil
      set_param(:url,             'http://' + get_param(:website_name))  # post path
    else
      set_param(:url,             'http://' + website_name)              # login path
    end
    url_string =  @metrics_admin_url + @metrics_params.slice(:module, :method, :url, :token_auth).to_query
    xstring = api_call(url_string)
    site_id = xstring.xpath('//idsite/text()').map(&:text)[0]
    site_id.to_i
  end

  def get_site_url
    set_param(:method,          'SitesManager.getSiteUrlsFromId')
    url_string =  @metrics_admin_url + @metrics_params.slice(:module, :method, :idSite, :token_auth).to_query
    xstring = api_call(url_string)
    site_urls = xstring.xpath('//row/text()').map(&:text)
    site_urls
  end

  def website_exists_in_piwik?(website_name=nil)
    site_id = get_site_id(website_name)
    result = (site_id != 0)
  end
#=======================================================================================================================
#   END:  WEBSITE METHODS
#=======================================================================================================================



#=======================================================================================================================
#   UTILITY  METHODS
#=======================================================================================================================

  def api_call(url_string)
    uri = URI.parse(url_string)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Get.new(uri.request_uri)
    http.read_timeout = get_param(:timeout)
    #todo use JSON calls where available vs xml
    if get_param(:action_name)=='ADMIN'
      xstring = Nokogiri::XML(open(url_string))
    else
      response = http.request(request)
      puts "Response: #{response.code} #{response.message} #{response.class.name}"
      puts "#{request}"
    end
  end

  def get_param(akey)
    @metrics_params[akey.to_sym]
  end

  def get_params
    @metrics_params
  end

  def hashit(toHash)
    Digest::MD5.hexdigest(toHash.to_s)
  end

  def is_customer_id_valid?
    @customer_id > 0
  end

  def metrics_admin_call(url_string)
    xstring = api_call(url_string)
    result = xstring.xpath('/result/success/@message')
    result.to_s == 'ok'
  end

  def post_metrics
    if get_param(:action_name) == "DONATION_RECEIVED"
      url_string = @metrics_post_url + @metrics_params.slice(:_id, :action_name, :apiv, :ec_id, :ecommerce, :idgoal,
                                                             :idsite, :patternType, :rec, :revenue, :send_image,
                                                             :timezone, :url, :uid, :ua).to_query

    elsif get_param(:action_name) == "FORM_DISPLAY"
      action = get_param(:action_name).to_s + "  " + "#{get_param(:website_name)}/#{get_param(:keyword).gsub(/-/, '_')}"
      set_param(:action_name, action)
      url_string = @metrics_post_url + @metrics_params.slice(:_id, :action_name, :apiv, :idsite, :patternType, :rec,
                                                             :send_image, :timezone, :url, :uid, :ua).to_query
    else
      url_string = @metrics_post_url + @metrics_params.slice(:action_name, :apiv, :idsite, :rec, :send_image, :timezone,
                                                             :url, :ua).to_query
    end
    api_call(url_string)
    url_string
  end

  def set_param(akey, avalue)
    @metrics_params[akey.to_sym] = avalue.to_s
  end
end

