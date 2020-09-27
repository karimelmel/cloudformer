class Buckets < CF_converter

  attr_accessor :name

  def convert_to_array(value)
    retval = value
    if !value.kind_of?(Array)
      retval = [value]
    end
    return retval
  end

  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)

    region_endpoints = {
      nil => "s3.amazonaws.com",
      "us-east-1" => "s3.amazonaws.com",
      "us-east-2" => "s3.us-east-2.amazonaws.com",
      "ca-central-1" => "s3.ca-central-1.amazonaws.com",
      "EU" => "s3-eu-west-1.amazonaws.com",
      "eu-west-1" => "s3-eu-west-1.amazonaws.com",
      "eu-west-2" => "s3-eu-west-2.amazonaws.com",
      "eu-west-3" => "s3-eu-west-3.amazonaws.com",
      "eu-central-1" => "s3.eu-central-1.amazonaws.com",
      "us-west-1" => "s3-us-west-1.amazonaws.com",
      "us-west-2" => "s3-us-west-2.amazonaws.com",
      "ap-south-1" => "s3-ap-south-1.amazonaws.com",
      "ap-southeast-1" => "s3-ap-southeast-1.amazonaws.com",
      "ap-southeast-2" => "s3-ap-southeast-2.amazonaws.com",
      "ap-northeast-1" => "s3-ap-northeast-1.amazonaws.com",
      "ap-northeast-2" => "s3-ap-northeast-2.amazonaws.com",
      "ap-northeast-3" => "s3-ap-northeast-3.amazonaws.com",
      "sa-east-1" => "s3-sa-east-1.amazonaws.com",
      "cn-north-1" => "s3.cn-north-1.amazonaws.com.cn",
      "cn-northwest-1" => "s3.cn-northwest-1.amazonaws.com.cn",
      "us-gov-west-1" => "s3-us-gov-west-1.amazonaws.com"
    }
    region_name = {
      nil => "us-east-1",
      "us-east-1" => "us-east-1",
      "us-east-2" => "us-east-2",
      "ca-central-1" => "ca-central-1",
      "EU" => "eu-west-1",
      "eu-west-1" => "eu-west-1",
      "eu-west-2" => "eu-west-2",
      "eu-west-3" => "eu-west-3",
      "eu-central-1" => "eu-central-1",
      "us-west-1" => "us-west-1",
      "us-west-2" => "us-west-2",
      "ap-south-1" => "ap-south-1",
      "ap-southeast-1" => "ap-southeast-1",
      "ap-southeast-2" => "ap-southeast-2",
      "ap-northeast-1" => "ap-northeast-1",
      "ap-northeast-2" => "ap-northeast-2",
      "ap-northeast-3" => "ap-northeast-3",
      "sa-east-1" => "sa-east-1",
      "cn-north-1" => "cn-north-1",
      "cn-northwest-1" => "cn-northwest-1",
      "us-gov-west-1" => "us-gov-west-1"
    }

    begin
      # Get all the S3 buckets we care about
      s3_global = AWS::S3.new(:s3_endpoint => region_endpoints[region])
      s3_buckets = []
      s3_global.client.list_buckets().data[:buckets].each do |bucket|
        # Flip to the specific endpoint for the bucket to retrieve info on the bucket
        begin
          bucket_location = s3_global.client.get_bucket_location(:bucket_name => bucket[:name]).data[:location_constraint]
          bucket_endpoint = region_endpoints[bucket_location]
          bucket_region = region_name[bucket_location]
        rescue
          bucket_region = "unknown"
        end
        if bucket_region == region
          s3 = AWS::S3.new(:s3_endpoint => bucket_endpoint)
          config = {:name => bucket[:name], :display_name => "#{bucket[:name]} (#{bucket_region})"}
          begin
            acls = s3.client.get_bucket_acl(:bucket_name => bucket[:name]).data
            config[:permissions] = acls if !acls.empty?
          rescue
            acls = []
          end
          begin
            cors = []
            raw_cors = s3.client.get_bucket_cors(:bucket_name => bucket[:name]).data[:rules]
            raw_cors.each do |rule|
              new_rule = {}
              rule.each do |key, value|
                new_rule[key] = value
              end
              cors << new_rule if !new_rule.empty?
            end
            config[:cors] = cors if !cors.empty?
          rescue => f
            cors = []
          end
          begin
            lifecycle = []
            raw_lifecycle = s3.client.get_bucket_lifecycle_configuration(:bucket_name => bucket[:name]).data[:rules]
            raw_lifecycle.each do |rule|
              new_lifecycle = {}
              rule.each do |key,value|
                if value.is_a?(Hash)
                  new_value = {}
                  value.each do |k, v|
                    new_value[k] = v.to_s
                  end
                  new_lifecycle[key] = new_value
                else
                  new_lifecycle[key] = value.to_s
                end
              end
              lifecycle << new_lifecycle if !new_lifecycle.empty?
            end
            config[:lifecycle] = lifecycle if !lifecycle.empty?
          rescue
            lifecycle = []
          end
          begin
            logging = s3.client.get_bucket_logging(:bucket_name => bucket[:name]).data
            config[:logging] = logging if !logging.empty?
          rescue
            logging = []
          end
          begin
            versioning = s3.client.get_bucket_versioning(:bucket_name => bucket[:name]).data
            config[:versioning] = versioning if ! versioning.empty?
          rescue
            versioning = []
          end
          begin
            tags = {}
            raw_tags = s3.client.get_bucket_tagging(:bucket_name => bucket[:name]).data[:tags]
            raw_tags.each do |key,value|
              tags[key] = value.to_s
            end
            config[:tags] = tags if !tags.empty?
          rescue
            tags = []
          end
          begin
            webs = s3.client.get_bucket_website(:bucket_name => bucket[:name]).data
            config[:website] = webs if !webs.empty?
          rescue
            webs = []
          end
          s3_buckets.push(config)
        end
      end
      all_resources.merge!({:buckets => s3_buckets})
    rescue => e
      all_errors.merge!({:buckets => e.message})
      all_resources.merge!({:buckets => {}})
    end
  end

  def self.ResourceName(resource)
    return "s3" + resource[:name].tr('^A-Za-z0-9', '')
  end

  def self.get_dependencies(resource, all_resources)
    bucket_policies = []
    if all_resources[:bucket_policies]
      all_resources[:bucket_policies].each do |policy|
        bucket_policies.push(policy) if resource[:name] == policy[:name]
      end
    end
    return { :bucket_policies => bucket_policies }
  end

  def self.OutputList(resource)
    return {"Bucket Name"        => "Name,Ref",
            "Bucket Domain Name" => "URL,GetAtt,DomainName",
            "Bucket Website URL" => "WebURL,GetAtt,WebsiteURL"}
  end

  def initialize(resource)
    @name = Buckets.ResourceName(resource)
    super(@name, "AWS::S3::Bucket")
  end

  def convert(resource, template, name_mappings)
    props = {}

    website = {}
    if resource[:website]
      website.merge!({ "IndexDocument" => resource[:website][:index_document][:suffix] }) if resource[:website][:index_document] && resource[:website][:index_document][:suffix]
      website.merge!({ "ErrorDocument" => resource[:website][:error_document][:key] }) if resource[:website][:error_document] && resource[:website][:error_document][:key]

      rules = []
      resource[:website][:routing_rules].each do |rule|
        condition = {}
        if rule[:condition]
          condition["KeyPrefixEquals"] = rule[:condition][:key_prefix_equals] if rule[:condition][:key_prefix_equals]
          condition["HttpErrorCodeReturnedEquals"] = rule[:condition][:http_error_code_returned_equals] if rule[:condition][:http_error_code_returned_equals]
        end
        redirect = {}
        if rule[:redirect]
          redirect["HostName"] = rule[:redirect][:host_name] if rule[:redirect][:host_name]
          redirect["HttpRedirectCode"] = rule[:redirect][:http_redirect_code] if rule[:redirect][:http_redirect_code]
          redirect["Protocol"] = rule[:redirect][:protocol] if rule[:redirect][:protocol]
          redirect["ReplaceKeyPrefixWith"] = rule[:redirect][:replace_key_prefix_with] if rule[:redirect][:replace_key_prefix_with]
          redirect["ReplaceKeyWith"] = rule[:redirect][:replace_key_with] if rule[:redirect][:replace_key_with]
        end
        new_rule = {}
        new_rule["RedirectRule"] = redirect if !redirect.empty?
        new_rule["RoutingRuleCondition"] = condition if !condition.empty?
        rules << new_rule if !new_rule.empty?
      end if resource[:website][:routing_rules]
      website.merge!({ "RoutingRules" => rules }) if !rules.empty?
    end
    props.merge!({"WebsiteConfiguration" => website}) if !website.empty?

    if resource[:permissions]
      access_control = "Private"
      resource[:permissions][:grants].each do |grant|
        if grant[:grantee] && grant[:grantee][:type] && grant[:grantee][:type].eql?("Group")
          if grant[:grantee][:uri].eql?("http://acs.amazonaws.com/groups/global/AllUsers")
            if grant[:permission] == :read
              access_control = "PublicRead"
            else
              access_control = "PublicReadWrite"
            end
          elsif grant[:grantee][:uri].eql?("http://acs.amazonaws.com/groups/global/AuthenticatedUsers")
            access_control = "AuthenticatedRead"
          elsif grant[:grantee][:uri].eql?("http://acs.amazonaws.com/groups/s3/LogDelivery")
            access_control = "LogDeliveryWrite"
          end
        end
      end if resource[:permissions][:grants]
      props.merge!({"AccessControl" => access_control})
    end

    cors_rules = []
    if resource[:cors]
      resource[:cors].each do |rule|
        new_rule = {}
          new_rule["AllowedHeaders"] = convert_to_array(rule[:allowed_headers]) if rule[:allowed_headers]
          new_rule["AllowedMethods"] = convert_to_array(rule[:allowed_methods]) if rule[:allowed_methods]
          new_rule["AllowedOrigins"] = convert_to_array(rule[:allowed_origins]) if rule[:allowed_origins]
          new_rule["ExposedHeaders"] = convert_to_array(rule[:exposed_headers]) if rule[:exposed_headers]
          new_rule["Id"] = rule[:id] if rule[:id]
          new_rule["MaxAge"] = rule[:max_age_seconds].to_s if rule[:max_age_seconds]
        cors_rules << new_rule if !new_rule.empty?
      end
    end
    props.merge!({"CorsConfiguration" => { "CorsRules" => cors_rules}}) if !cors_rules.empty?

    lifecycle_rules = []
    if resource[:lifecycle]
      resource[:lifecycle].each do |rule|
        new_rule = {}
        new_rule["ExpirationInDays"] = rule[:expiration][:days].to_s if rule[:expiration] && rule[:expiration][:days]
        new_rule["ExpirationDate"] = rule[:expiration][:date] if rule[:expiration] && rule[:expiration][:date]
        new_rule["Id"] = rule[:id] if rule[:id]
        new_rule["Prefix"] = rule[:prefix] if rule[:prefix]
        new_rule["Status"] = rule[:status] if rule[:status]

        transition = {}
        if rule[:transition]
          transition["StorageClass"] = (rule[:transition][:storage_class] == "GLACIER" ? "Glacier" : rule[:transition][:storage_class]) if rule[:transition][:storage_class]
          transition["TransitionInDays"] = rule[:transition][:days].to_s if rule[:transition][:days]
          transition["TransitionDate"] = rule[:transition][:date] if rule[:transition][:date]
        end
        new_rule["Transition"] = transition if !transition.empty?

        lifecycle_rules << new_rule if !new_rule.empty? && (new_rule["ExpirationDate"] || new_rule["ExpirationInDays"] || new_rule["Transition"])
      end
    end
    props.merge!({"LifecycleConfiguration" => { "Rules" => lifecycle_rules}}) if !lifecycle_rules.empty?

    if resource[:logging]  && resource[:logging][:logging_enabled]
      logging = {}
      logging["DestinationBucketName"] = ref_or_literal(:buckets, resource[:logging][:logging_enabled][:target_bucket], template, name_mappings) if resource[:logging][:logging_enabled][:target_bucket]
      logging["LogFilePrefix"] = resource[:logging][:logging_enabled][:target_prefix] if resource[:logging][:logging_enabled][:target_prefix]
      props.merge!({"LoggingConfiguration" => logging}) if !logging.empty?
    end

    if resource[:versioning] && resource[:versioning][:status]
      props.merge!({"VersioningConfiguration" => { "Status" => (resource[:versioning][:status] == :enabled) ? "Enabled" : "Suspended"}})
    end

    if resource[:tags]
      tags = []
      resource[:tags].each do |key, value|
        tags.push({"Key" => key, "Value" => value}) if value != nil && !key.starts_with?("aws:")
      end
      props.merge!({"Tags" => tags}) if !tags.empty?
    end

    return @cf_definition.deep_merge({ Buckets.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end

end
