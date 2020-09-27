class Bucket_Policies < CF_converter

  attr_accessor :name

  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)

    region_endpoints = {
      nil => "s3.amazonaws.com",
      "us-east-1" => "s3.amazonaws.com",
      "EU" => "s3-eu-west-1.amazonaws.com",
      "eu-west-1" => "s3-eu-west-1.amazonaws.com",
      "eu-west-2" => "s3-eu-west-2.amazonaws.com",
      "eu-west-3" => "s3-eu-west-3.amazonaws.com",
      "eu-central-1" => "s3.eu-central-1.amazonaws.com",
      "us-west-1" => "s3-us-west-1.amazonaws.com",
      "us-west-2" => "s3-us-west-2.amazonaws.com",
      "ap-southeast-1" => "s3-ap-southeast-1.amazonaws.com",
      "ap-southeast-2" => "s3-ap-southeast-2.amazonaws.com",
      "ap-south-1" => "s3.ap-south-1.amazonaws.com",
      "us-east-2" => "s3.us-east-2.amazonaws.com",
      "ca-central-1" => "s3.ca-central-1.amazonaws.com",
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
      "EU" => "eu-west-1",
      "eu-west-1" => "eu-west-1",
      "eu-west-2" => "eu-west-2",
      "eu-west-3" => "eu-west-3",
      "eu-central-1" => "eu-central-1",
      "us-west-1" => "us-west-1",
      "us-west-2" => "us-west-2",
      "ap-southeast-1" => "ap-southeast-1",
      "ap-southeast-2" => "ap-southeast-2",
      "ap-south-1" => "ap-south-1",
      "us-east-2" => "us-east-2",
      "ca-central-1" => "ca-central-1",
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
      s3_policies = []
      s3_global.buckets.each do |gbucket|
        # Flip to the specific endpoint for the bucket to retrieve info on the bucket
        begin
          bucket_endpoint = region_endpoints[gbucket.location_constraint]
          bucket_region = region_name[gbucket.location_constraint]
        rescue
          bucket_region = "unknown"
        end
        if bucket_region == region
          s3 = AWS::S3.new(:s3_endpoint => bucket_endpoint)
          bucket = s3.buckets[gbucket.name]
          policy = ""
          begin
            policy = s3.client.get_bucket_policy({:bucket_name => gbucket.name})[:policy]
          rescue
            # no policy on the bucket
          end
          s3_policies.push({:name => bucket.name, :display_name => "Bucket policy for #{bucket.name}", :policy => policy}) if policy!= ""
        end
      end
      all_resources.merge!({:bucket_policies => s3_policies})
    rescue => e
      all_errors.merge!({:bucket_policies => e.message})
      all_resources.merge!({:bucket_policies => {}})
    end
  end

  def self.ResourceName(resource)
    return "s3policy" + resource[:name].tr('^A-Za-z0-9', '')
  end

  def self.get_resource_attributes(resource)
    policy = ""
    policy = resource[:policy] if resource[:policy]
    return policy
  end

  def initialize(resource)
    @name = Bucket_Policies.ResourceName(resource)
    super(@name, "AWS::S3::BucketPolicy")
  end

  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"Bucket" => ref_or_literal(:buckets, resource[:name], template, name_mappings)}) if resource[:name]
    document = JSON.load(resource[:policy])
    document["Statement"].each do |statement|
       if statement["Resource"]
         if statement["Resource"].is_a?(String)
           arn = /arn:aws:s3:::(?<bucket_name>[a-z\-]+)(?<suffix>.*)/.match(statement["Resource"])
           statement["Resource"] = { "Fn::Join" => ["", ["arn:aws:s3:::", ref_or_literal(:buckets, arn[:bucket_name], template, name_mappings), arn[:suffix]]]}
         else
           reslist = []
           statement["Resource"].each do |resource|
           arn = /arn:aws:s3:::(?<bucket_name>[a-z\-]+)(?<suffix>.*)/.match(resource)
           reslist << { "Fn::Join" => ["", ["arn:aws:s3:::", ref_or_literal(:buckets, arn[:bucket_name], template, name_mappings), arn[:suffix]]]}
           statement["Resource"] = reslist
         end
        end
      end
    end if document["Statement"]
    props.merge!({"PolicyDocument" => document}) if resource[:policy]
    return @cf_definition.deep_merge({ Bucket_Policies.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end

end
