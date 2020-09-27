class DNS < CF_converter

  attr_accessor :name

  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the Route53 record sets we care about
      r53 = AWS::Route53.new()
      r53records = []
      r53.client.list_hosted_zones()[:hosted_zones].each do |zone|
        records = []
        r53.client.list_resource_record_sets(:hosted_zone_id => zone[:id])[:resource_record_sets].each do |rec|
          if rec[:type] != "SOA" && rec[:type] != "NS"
            name = rec[:name]
            name += rec[:set_identifier] if rec[:set_identifier]
            display = name.tr("^A-Za-z0-9", '')
            r53records << {
              :name => display,
              :target => rec[:name],
              :hosted_zone_id => zone[:id],
              :hosted_zone_name => zone[:name],
              :record_sets => [ rec ],
              :comment => zone[:comment]
            }
          end
        end
      end
      all_resources.merge!({:dns => r53records})
    rescue => e
      if region.eql?("us-gov-west-1")
        all_errors.merge!({:dns => "Not supported in the GovCloud (US) region"})
      else
        all_errors.merge!({:dns => e.message})
      end
      all_resources.merge!({:dns => {}})
    end
  end

  def self.get_dependencies(resource, all_resources)
    ec2Resources = []
    eipResources = []
    elbResources = []
    if !resource[:record_sets].empty? and resource[:record_sets][0][:resource_records]
      resource[:record_sets][0][:resource_records].each do |rr|
        if all_resources[:instances]
          all_resources[:instances].each do |instance|
            ec2Resources.push(instance) if rr.has_value?(instance[:ip_address])
          end
        end
        if all_resources[:eips]
          all_resources[:eips].each do |eip|
            eipResources.push(eip) if rr.has_value?(eip[:public_ip])
          end
        end
      end
    end
    if !resource[:record_sets].empty? and resource[:record_sets][0][:alias_target]
      at = resource[:record_sets][0][:alias_target]
      if all_resources[:elbs]
        all_resources[:elbs].each do |elb|
          elbResources.push(elb) if elb[:canonical_hosted_zone_name] && elb[:canonical_hosted_zone_name].casecmp(at[:dns_name].chop!) == 0
        end
      end
    end
    return { :instances => ec2Resources, :eips => eipResources, :elbs => elbResources }
  end

  def self.ResourceName(resource)
    return "dns" + resource[:name]
  end

  def self.get_resource_attributes(resource)
    desc = "Comment: #{resource[:comment]} \nHosted Zone: #{resource[:hosted_zone_id]}"
    if !resource[:record_sets].empty?
      desc += " \nRecord Type: #{resource[:record_sets][0][:type]}"
      desc += " \nSet Identifier: #{resource[:record_sets][0][:set_identifier]}" if resource[:record_sets][0][:set_identifier]
      desc += " \nWeight: #{resource[:record_sets][0][:weight]}" if resource[:record_sets][0][:weight]
      desc += " \nRegion: #{resource[:record_sets][0][:region]}" if resource[:record_sets][0][:region]
      desc += " \nAlias: #{resource[:record_sets][0][:alias_target][:dns_name]}" if resource[:record_sets][0][:alias_target] && resource[:record_sets][0][:alias_target][:dns_name]
      if resource[:record_sets][0][:resource_records]
        sep = " \nValue: "
        resource[:record_sets][0][:resource_records].each do |rec|
          desc += sep + rec[:value]
          sep = ","
        end
      end
    end
    return desc
  end

  def self.OutputList(resource)
    return {"Domain Name" => "Domain,Ref"}
  end

  def initialize(resource)
    @name = DNS.ResourceName(resource)
    super(@name, "AWS::Route53::RecordSetGroup")
  end

  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"HostedZoneName" => resource[:hosted_zone_name]}) if resource[:hosted_zone_name]
    props.merge!({"HostedZoneId" => resource[:hosted_zone_id]}) if resource[:hosted_zone_id] and !resource[:hosted_zone_name]
    props.merge!({"Comment" => resource[:comment]}) if resource[:comment]

    if resource[:record_sets]
      recs = []
      resource[:record_sets].each do |rec|
        rs = {}
        rs.merge!({"Name" => rec[:name]}) if rec[:name]
        rs.merge!({"Type" => rec[:type]}) if rec[:type]
        rs.merge!({"SetIdentifier" => rec[:set_identifier].to_s}) if rec[:set_identifier]
        rs.merge!({"Weight" => rec[:weight].to_s}) if rec[:weight]
        rs.merge!({"TTL" => rec[:ttl].to_s}) if rec[:ttl]

        if rec[:resource_records]
          val = []
          rec[:resource_records].each do |v|
            tmp = ref_or_literal(:eips, v[:value], template, name_mappings)
            tmp = ref_or_getatt(:instances, v[:value], :ip_address, "PublicIp", template, name_mappings) if tmp.class == String
            val.push(tmp)
          end
          rs.merge!({"ResourceRecords" => val})
        end

        if rec[:alias_target]
          a = {}
          a.merge!({ "HostedZoneId" => ref_or_getatt(:elbs, rec[:alias_target][:hosted_zone_id], :canonical_hosted_zone_name_id, "CanonicalHostedZoneNameID", template, name_mappings)})
          a.merge!({ "DNSName" => ref_or_getatt(:elbs, rec[:alias_target][:dns_name].chop!, :canonical_hosted_zone_name, "CanonicalHostedZoneName", template, name_mappings)})
          rs.merge!({"AliasTarget" => a})
        end

        recs.push(rs)
      end
      props.merge!({"RecordSets" => recs})
    end

    return @cf_definition.deep_merge({ DNS.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end

end
