
require 'chef/node'

class Chef::ResourceDefinitionList::OpsWorksHelper

  # true if we're on opsworks, false otherwise
  def self.opsworks?(node)
    node['opsworks'] != nil
  end

  # return Chef Nodes for this replicaset / layer
  def self.replicaset_members(node)
    Chef::Log.info('OpsWorks replicaset members')

    members = []
    # FIXME -> this is bad, we're assuming replicaset instances use a single layer
    replicaset_layer_slug_name = node['opsworks']['instance']['layers'].first
    instances = node['opsworks']['layers'][replicaset_layer_slug_name]['instances']
    node_conf = Chef::DataBagItem.load(
      replicaset_layer_slug_name,
      node['opsworks']['instance']['hostname']
    )
    instances.each do |name, instance|
      bag_conf = Chef::DataBagItem.load(replicaset_layer_slug_name, name)
      if instance['status'] == 'online' and \
          node_conf['mongodb']['config']['replSet'] == bag_conf['mongodb']['config']['replSet']
        member = Chef::Node.new
        member.name(name)
        member.default['fqdn'] = instance['private_dns_name']
        member.default['ipaddress'] = instance['private_ip']
        member.default['hostname'] = name
        mongodb_attributes = {
          # here we could support a map of instances to custom replicaset options in the custom json
          'port' => node['mongodb']['config']['port'],
          'replica_arbiter_only' => bag_conf['mongodb']['replica_arbiter_only'] || false,
          'replica_build_indexes' => bag_conf['mongodb']['replica_build_indexes'] || true,
          'replica_hidden' => bag_conf['mongodb']['replica_hidden'] || false,
          'replica_slave_delay' => bag_conf['mongodb']['replica_slave_delay'] || 0,
          'replica_priority' => bag_conf['mongodb']['replica_priority'] || 1,
          'replica_tags' => bag_conf['mongodb']['replica_tags'] || {}, # to_hash is called on this
          'replica_votes' => bag_conf['mongodb']['replica_votes'] || 1
        }
        member.default['mongodb'] = mongodb_attributes
        members << member
      end
    end
    members
  end

  def self.configserv_members(node)
    Chef::Log.info('OpsWorks configserv members')

    members = []
    replicaset_layer_slug_name = node['opsworks']['instance']['layers'].first
    instances = node['opsworks']['layers'][replicaset_layer_slug_name]['instances']
    node_conf = Chef::DataBagItem.load(
      replicaset_layer_slug_name,
      node['opsworks']['instance']['hostname']
    )
    instances.each do |name, instance|
      bag_conf = Chef::DataBagItem.load(replicaset_layer_slug_name, name)
      if instance['status'] == 'online' and \
          node_conf['mongodb']['config']['replSet'] == bag_conf['mongodb']['config']['replSet']
        member = Chef::Node.new
        member.name(name)
        member.default['fqdn'] = instance['private_dns_name']
        member.default['ipaddress'] = instance['private_ip']
        member.default['hostname'] = name
        member.default['mongodb'] = {}

        bag_conf.each do |k, v|
          member.default['mongodb'][k] = v
        end
        members << member
      end
    end
    members
  end

end
