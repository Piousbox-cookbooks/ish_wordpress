#
# Cookbook Name:: ish_wordpress
# Recipe:: default
#
# Copyright 2016, wasya.co
#
# All rights reserved - Do Not Redistribute
#

%w{ ruby-dev awscli }.each do |pkg|
  package pkg
end

app                                              = data_bag_item('apps', node['apache2']['wp_site'])
node.default['wordpress']['dir']                 = app['document_root'][node.chef_environment]
node.default['wordpress']['db']['root_password'] = app['databases'][node.chef_environment]['password']
node.default['wordpress']['db']['name']          = app['databases'][node.chef_environment]['database']
node.default['wordpress']['db']['user']          = app['databases'][node.chef_environment]['username']
node.default['wordpress']['db']['pass']          = app['databases'][node.chef_environment]['password']
node.default['wordpress']['db']['password']      = app['databases'][node.chef_environment]['password']
node.default['wordpress']['db']['host']          = app['databases'][node.chef_environment]['host']
node.default['wordpress']['server_name']         = app['domains'][node.chef_environment][0]
node.default['wordpress']['server_aliases']      = app['domains'][node.chef_environment][1..-1]

user                                             = app['user'][node.chef_environment]
mysql_user                                       = app['databases'][node.chef_environment]['username']
mysql_password                                   = app['databases'][node.chef_environment]['password']
mysql_host                                       = app['databases'][node.chef_environment]['host']
mysql_database                                   = app['databases'][node.chef_environment]['database']
aws_key                                          = app['aws_key'][node.chef_environment]
aws_secret                                       = app['aws_secret'][node.chef_environment]
restore_name                                     = app['restore_name'][node.chef_environment] # YYYYMMDD.db_name
restore_path                                     = "ish-backups/sql_backup/#{restore_name}.sql.tar.gz"
document_root                                    = app['document_root'][node.chef_environment]


include_recipe "wordpress::default"

package "libapache2-mod-php5" do
  action [ :remove, :install ]
end


template "#{document_root}/wp-config.php" do
  source "wp-config.php.erb"
  owner  user
  group  user
  mode   "0664"
  variables({
              :db_host      => mysql_host,
              :db_user      => mysql_user,
              :db_password  => mysql_password,
              :db_name      => mysql_database
  })
end


# create database if missing
# migrate old dataz
execute   "restore data" do
  cwd     "/home/#{user}/projects"
  not_if  "mysql -u#{mysql_user} -p#{mysql_password} -h #{mysql_host} -se'USE #{mysql_database};' 2>&1"
  command <<-EOL
rm -f *sql* ; \
echo "create database #{mysql_database}" > trash.sql && \
mysql -u #{mysql_user} -p#{mysql_password} -h #{mysql_host} < trash.sql && \
AWS_ACCESS_KEY_ID=#{aws_key} AWS_SECRET_ACCESS_KEY=#{aws_secret} aws s3 cp s3://#{restore_path} . --region us-west-1 && \
tar -xvf #{restore_name}.sql.tar.gz && \
mysql -u #{mysql_user} -p#{mysql_password} -h #{mysql_host} #{mysql_database} < #{restore_name}.sql && \
echo ok
EOL
end








