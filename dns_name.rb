# Bastardized from cap-ec2-1.0.0/lib/cap-ec2/ec2-handler.rb
#
# AWS_ACCESS_KEY_ID=x AWS_SECRET_ACCESS_KEY=y ruby dns_name.rb production App puma your-domain.com
# AWS_ACCESS_KEY_ID=x AWS_SECRET_ACCESS_KEY=y ruby dns_name.rb production Worker worker your-domain.com

require 'rubygems'
require 'bundler/setup'
require 'aws-sdk'

unless ARGV.count >= 4
  puts "You must specify an environment, role name, EC2 role and FQDN"
  puts "e.g. AWS_ACCESS_KEY_ID=x AWS_SECRET_ACCESS_KEY=y ruby production App puma your-domain.com"
  exit 1
end

# set :ec2_project_tag, 'Project'
# set :ec2_roles_tag, 'Roles'
# set :ec2_stages_tag, 'Stages'

def application
  'api.your-domain.com'
end

def roles_tag
  'Roles'
end

def stages_tag
  'Stages'
end

def stage
  ARGV[0]
end

def project_tag
  'Project'
end

def tag(tag_name)
  "tag:#{tag_name}"
end

def configured_regions
  ['ap-southeast-2']
end

def get_servers_for_role(ec2, role)
  servers = []
  ec2.each do |_, ec2|
    instances = ec2.instances
                  .filter(tag(project_tag), "*#{application}*")
                  .filter('instance-state-name', 'running')
    servers << instances.select do |i|
      instance_has_tag?(i, roles_tag, role) &&
        instance_has_tag?(i, stages_tag, stage) &&
        instance_has_tag?(i, project_tag, application) # &&
        # (fetch(:ec2_filter_by_status_ok?) ? instance_status_ok?(i) : true)
    end
  end
  servers.flatten.sort_by {|s| s.tags["Name"] || ''}
end

def instance_has_tag?(instance, key, value)
  (instance.tags[key] || '').split(',').map(&:strip).include?(value.to_s)
end

def for_each_region
  ec2 = {}
  configured_regions.each do |region|
    ec2[region] = ec2_connect(region)
  end
  ec2
end

def ec2_connect(region=nil)
  AWS::EC2.new(
    access_key_id: ENV['AWS_ACCESS_KEY_ID'],
    secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
    region: region
  )
end

def contact_point_mapping
  {
    :public_dns => :public_dns_name,
    :public_ip => :public_ip_address,
    :private_ip => :private_ip_address
  }
end

def ip_address_or_dns(instance)
  ec2_interface = contact_point_mapping[:public_ip]
  return instance.send(ec2_interface) if ec2_interface
  instance.public_dns_name || instance.public_ip_address || instance.private_ip_address
end

def calc_next_name_for_role(ec2, env, role, role_tag)
  max_count = 1
  seen_ids = []
  api_servers = get_servers_for_role(ec2, role_tag).sort_by(&:launch_time)
  api_servers.each do |s|
    name_id = s.tags['Name'].sub(/\A.*\-(\d+)\z/, '\1').to_i
    max_count = name_id if name_id > max_count
    max_count += 1 if seen_ids.include?(name_id)
    seen_ids.push(name_id).uniq!
  end
  "#{env}-#{role}-#{max_count + 1}"
end

ec2 = for_each_region
new_hostname = calc_next_name_for_role(ec2, ARGV[0], ARGV[1], ARGV[2])
puts "Your new hostname is.... #{new_hostname}.#{ARGV[3]} \u{1F389}"
`hostname #{new_hostname}.#{ARGV[3]}`

# `service newrelic-sysmond restart`

f = File.open('/etc/hostname', 'w')
f.puts("#{new_hostname}.#{ARGV[3]}")
f.close

