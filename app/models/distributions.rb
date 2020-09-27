class Distributions < CF_converter
  
  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the CloudFront distributions we care about
      cf = AWS::CloudFront.new()
      distributions = []
      cf.client.list_distributions().data[:items].each do |dist|
        dist_detail = cf.client.get_distribution_config({:id => dist[:id]})
        full_dist = dist.clone
        full_dist.reject!{ |k| k == :last_modified_time }
        full_dist[:default_root_object] = dist_detail[:default_root_object] if dist_detail[:default_root_object]
        full_dist[:logging] = dist_detail[:logging] if dist_detail[:logging]
        distributions << full_dist
      end
      all_resources.merge!({:distributions => distributions})
    rescue => e
      if region.eql?("us-gov-west-1")
        all_errors.merge!({:distributions => "Not supported in this region"})
      else
        all_errors.merge!({:distributions => e.message})
      end
      all_resources.merge!({:distributions => {}})
    end
  end
  
  def self.ResourceName(resource)
    return "dist" + resource[:domain_name].tr('^A-Za-z0-9', '')
  end
  
  def self.get_resource_attributes(resource)
    return "Comment: #{resource[:comment]} \n" +
           "Enabled: #{resource[:enabled]}"
  end
  
  def self.OutputList(resource)
    return {"Distribution Id" => "Name,Ref",
            "Domain Name" => "Domain,GetAtt,DomainName"}
  end

  def initialize(resource)
    @name = Distributions.ResourceName(resource)
    super(@name, "AWS::CloudFront::Distribution")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"Aliases" => resource[:aliases][:items]}) if resource[:aliases] && resource[:aliases][:items] && !resource[:aliases][:items].empty?
    props.merge!({"Comment" => resource[:comment]}) if resource[:comment]
    props.merge!({"Enabled" => resource[:enabled]}) if resource[:enabled]
    props.merge!({"DefaultRootObject" => resource[:default_root_object]}) if resource[:default_root_object]
    props.merge!({"PriceClass" => resource[:price_class]}) if resource[:price_class]

    custom_errors = []
    if resource[:custom_error_responses]
      resource[:custom_error_responses][:items].each do |error_response|
        custom_error = {}
        custom_error.merge!({"ErrorCachingMinTTL" => error_response[:error_caching_min_ttl] }) if error_response[:error_caching_min_ttl]
        custom_error.merge!({"ErrorCode" => error_response[:error_code]}) if error_response[:error_code]
        custom_error.merge!({"ResponseCode" => error_response[:response_code]}) if error_response[:response_code]
        custom_error.merge!({"ResponsePagePath" => error_response[:response_path_path]}) if error_response[:response_page_path]
        custom_errors << custom_error if !custom_error.empty?
      end
      props.merge!({"CustomErrorResponses" => custom_errors}) if !custom_errors.empty?
    end

    cache_behaviors = []
    if resource[:cache_behaviors]
      resource[:cache_behaviors][:items].each do |cache|
        cache_behavior = {}
        cache_behavior.merge!({"TargetOriginId" => cache[:target_origin_id]}) if cache[:target_origin_id]
        cache_behavior.merge!({"PathPattern" => cache[:path_pattern]}) if cache[:path_pattern]
        cache_behavior.merge!({"SmoothStreaming" => cache[:smooth_streaming]}) if cache[:smooth_streaming]
        cache_behavior.merge!({"ViewerProtocolPolicy" => cache[:viewer_protocol_policy]}) if cache[:viewer_protocol_policy]
        cache_behavior.merge!({"MinTTL" => cache[:min_ttl]}) if cache[:min_ttl]
        cache_behavior.merge!({"TrustedSigners" => cache[:trusted_signers][:items]}) if cache[:trusted_signers] && cache[:trusted_signers][:items] && !cache[:trusted_signers][:items].empty?
        cache_behavior.merge!({"AllowedMethods" => cache[:allowed_methods][:items]}) if cache[:allowed_methods]
        cache_behavior.merge!({"CachedMethods" => cache[:allowed_methods][:cached_methods][:items]}) if cache[:allowed_methods] && cache[:allowed_methods][:cached_methods]

        if cache[:forwarded_values]
          forwarded_values = {}
          forwarded_values.merge!({"QueryString" => cache[:forwarded_values][:query_string]}) if cache[:forwarded_values][:query_string]
          forwarded_values.merge!({"Headers" => cache[:forwarded_values][:headers][:items]}) if cache[:forwarded_values][:headers] && !cache[:forwarded_values][:headers][:items].empty?
          if cache[:forwarded_values][:cookies]
            cookies = {}
            cookies.merge!({"Forward" => cache[:forwarded_values][:cookies][:forward]}) if cache[:forwarded_values][:cookies][:forward]
            cookies.merge!({"WhiteListedNames" => cache[:forwarded_values][:cookies][:whitelisted_names][:items]}) if  cache[:forwarded_values][:cookies][:whitelisted_names]
            forwarded_values.merge!({"Cookies" => cookies}) if !cookies.empty?
          end
          cache_behavior.merge!({"ForwardedValues" => forwarded_values}) if !forwarded_values.empty?
        end

        cache_behaviors << cache_behavior if !cache_behavior.empty?
      end
      props.merge!({"CacheBehaviors" => cache_behaviors}) if !cache_behaviors.empty?
    end
    
    if resource[:default_cache_behavior]
      default_cache_behavior = {}
      default_cache_behavior.merge!({"TargetOriginId" => resource[:default_cache_behavior][:target_origin_id]}) if resource[:default_cache_behavior][:target_origin_id]
      default_cache_behavior.merge!({"PathPattern" =>  resource[:default_cache_behavior][:path_pattern]}) if  resource[:default_cache_behavior][:path_pattern]
      default_cache_behavior.merge!({"SmoothStreaming" =>  resource[:default_cache_behavior][:smooth_streaming]}) if  resource[:default_cache_behavior][:smooth_streaming]
      default_cache_behavior.merge!({"ViewerProtocolPolicy" => resource[:default_cache_behavior][:viewer_protocol_policy]}) if resource[:default_cache_behavior][:viewer_protocol_policy]
      default_cache_behavior.merge!({"MinTTL" => resource[:default_cache_behavior][:min_ttl]}) if resource[:default_cache_behavior][:min_ttl]
      default_cache_behavior.merge!({"TrustedSigners" => resource[:default_cache_behavior][:trusted_signers][:items]}) if resource[:default_cache_behavior][:trusted_signers] && resource[:default_cache_behavior][:trusted_signers][:items] && !resource[:default_cache_behavior][:trusted_signers][:items].empty?
      default_cache_behavior.merge!({"AllowedMethods" =>  resource[:default_cache_behavior][:allowed_methods][:items]}) if  resource[:default_cache_behavior][:allowed_methods]
      default_cache_behavior.merge!({"CachedMethods" => resource[:default_cache_behavior][:allowed_methods][:cached_methods][:items]}) if resource[:default_cache_behavior][:allowed_methods] && resource[:default_cache_behavior][:allowed_methods][:cached_methods]

      if resource[:default_cache_behavior][:forwarded_values]
        forwarded_values = {}
        forwarded_values.merge!({"QueryString" => resource[:default_cache_behavior][:forwarded_values][:query_string]}) if resource[:default_cache_behavior][:forwarded_values][:query_string]
        forwarded_values.merge!({"Headers" => resource[:default_cache_behavior][:forwarded_values][:headers][:items]}) if resource[:default_cache_behavior][:forwarded_values][:headers] && !resource[:default_cache_behavior][:forwarded_values][:headers][:items].empty?
        if resource[:default_cache_behavior][:forwarded_values][:cookies]
          cookies = {}
          cookies.merge!({"Forward" => resource[:default_cache_behavior][:forwarded_values][:cookies][:forward]}) if resource[:default_cache_behavior][:forwarded_values][:cookies][:forward]
          cookies.merge!({"WhiteListedNames" => resource[:default_cache_behavior][:forwarded_values][:cookies][:whitelisted_names][:items]}) if  resource[:default_cache_behavior][:forwarded_values][:cookies][:whitelisted_names]
          forwarded_values.merge!({"Cookies" => cookies}) if !cookies.empty?
        end
        
        default_cache_behavior.merge!({"ForwardedValues" => forwarded_values}) if !forwarded_values.empty?
      end

      props.merge!({"DefaultCacheBehavior" => default_cache_behavior}) if !default_cache_behavior.empty?
    end

    if resource[:logging] && resource[:logging][:enabled]
      logging = {}
      logging.merge!({"Bucket" => resource[:logging][:bucket]}) if resource[:logging][:bucket]
      logging.merge!({"IncludeCookies" => resource[:logging][:include_cookies]}) if resource[:logging][:include_cookies]
      logging.merge!({"Prefix" => resource[:logging][:prefix]}) if resource[:logging][:prefix]
      props.merge!({"Logging" => logging}) if !logging.empty?
    end
    
    origins = []
    if resource[:origins]
      resource[:origins][:items].each do |origin|
        new_origin = {}
        new_origin.merge!({"DomainName" => origin[:domain_name]}) if origin[:domain_name]
        new_origin.merge!({"Id" => origin[:id]}) if origin[:id]
        new_origin.merge!({"OriginPath" => origin[:origin_path]}) if origin[:origin_path]
        if origin[:s3_origin_config]
          s3origin = {}
          s3origin.merge!({"OriginAccessIdentity" => origin[:s3_origin_config][:origin_access_identity]}) if origin[:s3_origin_config][:origin_access_identity]
          new_origin.merge!({"S3OriginConfig" => s3origin})
        elsif origin[:custom_origin_config]
          custom = {}
          custom.merge!({"HTTPPort" => origin[:custom_origin_config][:http_port].to_s}) if origin[:custom_origin_config][:http_port]
          custom.merge!({"HTTPSPort" => origin[:custom_origin_config][:https_port].to_s}) if origin[:custom_origin_config][:https_port]
          custom.merge!({"OriginProtocolPolicy" => origin[:custom_origin_config][:origin_protocol_policy]}) if origin[:custom_origin_config][:origin_protocol_policy]
          new_origin.merge!({"S3OriginConfig" => custom})
        end
        origins << new_origin if !new_origin.empty?
      end
      props.merge!({"Origins" => origins}) if !origins.empty?
    end

    if resource[:restrictions] && resource[:restrictions][:geo_restriction]
      geo_restriction = {}
      geo_restriction.merge!({"RestrictionType" => resource[:restrictions][:geo_restriction][:restriction_type]}) if resource[:restrictions][:geo_restriction][:restriction_type]
      geo_restriction.merge!({"Locations" => resource[:restrictions][:geo_restriction][:items]}) if resource[:restrictions][:geo_restriction][:items]
      props.merge!({"Restrictions" => {"GeoRestriction" => geo_restriction}}) if !geo_restriction.empty?
    end

    if resource[:viewer_certificate]
      viewer_cert = {}
      viewer_cert.merge!({"CloudFrontDefaultCertificate" => resource[:viewer_certificate][:cloud_front_default_certificate].to_s()}) if resource[:viewer_certificate][:cloud_front_default_certificate]
      viewer_cert.merge!({"IamCertificateId" => resource[:viewer_certificate][:iam_certificate_id].to_s()}) if resource[:viewer_certificate][:iam_certificate_id]
      viewer_cert.merge!({"SslSupportMethod" => resource[:viewer_certificate][:ssl_support_method].to_s()}) if resource[:viewer_certificate][:ssl_support_method]
      viewer_cert.merge!({"MinimumProtocolVersion" => resource[:viewer_certificate][:minimum_protocol_version].to_s()}) if resource[:viewer_certificate][:minimum_protocol_version]
      props.merge!({"ViewerCertificate" => viewer_cert}) if !viewer_cert.empty?
    end

    return @cf_definition.deep_merge({ Distributions.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => {"DistributionConfig" => props }}})
  end
    
end
