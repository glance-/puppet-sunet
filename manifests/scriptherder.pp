# Scriptherder jobs

# Run a cronjob and create a scriptherder monitoring file
define sunet::scriptherder::cronjob(
  # cron parameters
  $cron_cmd,
  $cron_user                = 'root',
  $cron_special             = undef,    # 'daily'
  # scriptherder parameters
  $ok_criteria              = ['exit_status=0'],
  $warn_criteria            = [],
) {
  # used in template scriptherder_check.ini.erb
  $scriptherder_ok = join($ok_criteria, ', ')
  $scriptherder_warn = join($warn_criteria, ', ')

  file { "/etc/scriptherder/check/${name}.ini" :
    ensure  => 'file',
    mode    => '644', # to allow NRPE to read it
    group   => 'root',
    content => template('sunet/scriptherder/scriptherder_check.ini.erb'),
  } ->

  cron { $name:
    command  => "/usr/local/bin/scriptherder --mode wrap --syslog --name ${name} -- ${cron_cmd}",
    user     => $cron_user,
    special  => $cron_special,
  }
}