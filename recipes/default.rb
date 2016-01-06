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
projects_dir                                     = "/home/#{user}/projects"

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

#
# NEVER RUNS!
# migrate data
# ONLY IF database does not exist
#
execute   "restore data" do
  cwd     projects_dir
  not_if  "mysql -u#{mysql_user} -p#{mysql_password} -h #{mysql_host} -se'USE #{mysql_database};' 2>&1"
  only_if false
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



#
# configure FoundationPress
#
execute "clone FoundationPress" do
  cwd "#{document_root}/wp-content/themes"
  command "git clone https://github.com/piousbox/FoundationPress.git"
  not_if { ::File.exists?( "#{document_root}/wp-content/themes/FoundationPress" ) }
end
execute "update FoundationPress" do
  cwd "#{document_root}/wp-content/themes/FoundationPress"
  command "git pull origin master"
end

execute "get wp cli" do
  cwd document_root
  command "curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar"
  not_if { ::File.exists?( "#{document_root}/wp-cli.phar" ) }
end

execute "activate FoundationPress" do
  cwd document_root
  user user
  command "php wp-cli.phar theme activate FoundationPress"
end

service "apache2" do
  action :reload
end





