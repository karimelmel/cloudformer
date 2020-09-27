class R53_Recordsets < CF_converter

  attr_accessor :name

  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the Route53 record sets we care about
      r53 = AWS::Route53.new()
      r53records = []
      r53.client.list_hosted_zones()[:hosted_zones].each do |zone|
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
      all_resources.merge!({:r53_recordsets => r53records})
    rescue => e
      if region.eql?("us-gov-west-1")
        all_errors.merge!({:r53_recordsets => "Not supported in this region"})
      else
        all_errors.merge!({:r53_recordsets => e.message})
      end
      all_resources.merge!({:r53_recordsets => {}})
    end
  end

  def self.get_dependencies(resource, all_resources)
    ec2Resources = []
    eipResources = []
    elbResources = []
    if !resource[:record_sets].empty? && resource[:record_sets][0][:resource_records]
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
    if !resource[:record_sets].empty? && resource[:record_sets][0][:alias_target]
      at = resource[:record_sets][0][:alias_target]
      if all_resources[:elbs]
        all_resources[:elbs].each do |elb|
          elbResources.push(elb) if  elb[:canonical_hosted_zone_name] && elb[:canonical_hosted_zone_name].casecmp(at[:dns_name].chop!) == 0
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
    @name = R53_Recordsets.ResourceName(resource)
    super(@name, "AWS::Route53::RecordSetGroup")
  end

  def convert(resource, template, name_mappings)
    props = {}
    zone = ref_or_literal(:r53_hostedzones, resource[:hosted_zone_name], template, name_mappings)
    if zone.class == String
      props.merge!({"HostedZoneName" => zone})
    else
      props.merge!({"HostedZoneId" => zone})
    end
    props.merge!({"Comment" => resource[:comment]}) if resource[:comment]

    if resource[:record_sets]
      recs = []
      resource[:record_sets].each do |rec|
        rs = {}
        rs.merge!({"Failover" => rec[:failover]}) if rec[:failover]
        rs.merge!({"Name" => rec[:name]}) if rec[:name]
        rs.merge!({"Region" => rec[:region]}) if rec[:region]
        rs.merge!({"SetIdentifier" => rec[:set_identifier].to_s}) if rec[:set_identifier]
        rs.merge!({"Type" => rec[:type]}) if rec[:type]
        rs.merge!({"TTL" => rec[:ttl].to_s}) if rec[:ttl]
        rs.merge!({"Weight" => rec[:weight].to_s}) if rec[:weight]

        rs.merge!({"HealthCheckId" => ref_or_literal(:r53_healthchecks, rec[:health_check_id], template, name_mappings)}) if rec[:health_check_id]

        if rec[:geo_location]
          geo = {}
          geo["ContinentCode"] = rec[:geo_location][:continent_code] if rec[:geo_location][:continent_code]
          geo["CountryCode"] = rec[:geo_location][:country_code] if rec[:geo_location][:country_code]
          geo["SubdivisionCode"] = rec[:geo_location][:subdivision_code] if rec[:geo_location][:subdivision_code]
          rs["GeoLocation"] = geo if !geo.empty?
        end

        if rec[:resource_records]
          val = []
          rec[:resource_records].each do |v|
            tmp = ref_or_literal(:eips, v[:value], template, name_mappings)
            tmp = ref_or_getatt(:instances, v[:value], :ip_address, "PublicIp", template, name_mappings) if tmp.class == String
            val.push(tmp)
          end
          rs["ResourceRecords"] = val if !val.empty?
        end

        if rec[:alias_target]
          a = {}
          a["HostedZoneId"] = ref_or_getatt(:elbs, rec[:alias_target][:hosted_zone_id], :canonical_hosted_zone_name_id, "CanonicalHostedZoneNameID", template, name_mappings)
          a["DNSName"] = ref_or_getatt(:elbs, rec[:alias_target][:dns_name].chop!, :canonical_hosted_zone_name, "CanonicalHostedZoneName", template, name_mappings)
          a["EvaluateTargetHealth"] = rec[:alias_target][:evaluate_target_health] if rec[:alias_target][:evaluate_target_health]
          rs["AliasTarget"] = a if !a.empty?
        end

        recs.push(rs)
      end
      props.merge!({"RecordSets" => recs})
    end

    return @cf_definition.deep_merge({ R53_Recordsets.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end

end
